import asyncio
from datetime import datetime, timedelta, timezone
import json

import httpx

from app.grounded_provider import GeminiGroundedEventProvider, GroundedSearchLimitReached
from app.usage import MonthlyUsageLedger


def grounded_payload(source_url: str, start_at: datetime) -> dict:
    return {
        "candidates": [
            {
                "content": {
                    "parts": [
                        {
                            "text": json.dumps(
                                {
                                    "events": [
                                        {
                                            "title": "Example Japan Tour",
                                            "start_at": start_at.isoformat(),
                                            "venue_name": "Tokyo Dome",
                                            "city": "Tokyo",
                                            "source_url": source_url,
                                        }
                                    ]
                                }
                            )
                        }
                    ]
                },
                "groundingMetadata": {
                    "groundingChunks": [{"web": {"uri": source_url}}]
                },
            }
        ]
    }


def test_grounded_provider_returns_confirmation_candidate(tmp_path) -> None:
    source_url = "https://artist.example/live"
    start_at = datetime.now(timezone.utc) + timedelta(days=30)

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=grounded_payload(source_url, start_at))

    async def run_search():
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            provider = GeminiGroundedEventProvider(
                "test-key",
                "test-model",
                client,
                MonthlyUsageLedger(str(tmp_path / "usage.sqlite3")),
                monthly_request_limit=10,
            )
            return await provider.search("Example", "JP")

    events = asyncio.run(run_search())
    assert len(events) == 1
    assert events[0].provider == "gemini_grounded"
    assert events[0].requires_confirmation is True
    assert events[0].source_url == source_url


def test_grounded_provider_rejects_uncited_event(tmp_path) -> None:
    payload = grounded_payload(
        "https://artist.example/live",
        datetime.now(timezone.utc) + timedelta(days=30),
    )
    payload["candidates"][0]["groundingMetadata"]["groundingChunks"] = []

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=payload)

    async def run_search():
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            provider = GeminiGroundedEventProvider(
                "test-key",
                "test-model",
                client,
                MonthlyUsageLedger(str(tmp_path / "usage.sqlite3")),
                monthly_request_limit=10,
            )
            return await provider.search("Example", "JP")

    assert asyncio.run(run_search()) == []


def test_grounded_provider_persists_monthly_limit(tmp_path) -> None:
    request_count = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal request_count
        request_count += 1
        return httpx.Response(200, json={"candidates": []})

    async def run_searches() -> None:
        database_path = str(tmp_path / "usage.sqlite3")
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            first_provider = GeminiGroundedEventProvider(
                "test-key",
                "test-model",
                client,
                MonthlyUsageLedger(database_path),
                monthly_request_limit=1,
            )
            assert await first_provider.search("Example", "JP") == []
            second_provider = GeminiGroundedEventProvider(
                "test-key",
                "test-model",
                client,
                MonthlyUsageLedger(database_path),
                monthly_request_limit=1,
            )
            try:
                await second_provider.search("Another", "JP")
            except GroundedSearchLimitReached:
                pass
            else:
                raise AssertionError("Expected persistent monthly limit")

    asyncio.run(run_searches())
    assert request_count == 1
