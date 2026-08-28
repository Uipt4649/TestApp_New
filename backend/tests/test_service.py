import asyncio
from datetime import datetime, timezone

import httpx

from app.config import Settings
from app.models import EventResult
from app.service import EventSearchService, deduplicate_events, fallback_artist_name


def test_fallback_artist_name_removes_common_request_suffix() -> None:
    assert fallback_artist_name("あいみょんのライブ情報を調べて") == "あいみょん"


def test_deduplicate_events_prefers_bandsintown_source() -> None:
    start_at = datetime(2026, 10, 1, 10, 0, tzinfo=timezone.utc)
    ticketmaster = EventResult(
        provider="ticketmaster",
        provider_event_id="tm-1",
        title="Example Live",
        start_at=start_at,
        venue_name="Tokyo Dome",
        source_url="https://example.com/tm",
    )
    bandsintown = EventResult(
        provider="bandsintown",
        provider_event_id="bit-1",
        title="Example Live",
        start_at=start_at,
        venue_name="Tokyo Dome",
        source_url="https://example.com/bit",
    )

    assert deduplicate_events([ticketmaster, bandsintown]) == [bandsintown]


def test_deduplicate_events_never_replaces_api_event_with_ai_candidate() -> None:
    start_at = datetime(2026, 10, 1, 10, 0, tzinfo=timezone.utc)
    ticketmaster = EventResult(
        provider="ticketmaster",
        provider_event_id="tm-1",
        title="Example Live",
        start_at=start_at,
        venue_name="Tokyo Dome",
        source_url="https://example.com/tm",
    )
    ai_candidate = EventResult(
        provider="gemini_grounded",
        provider_event_id="ai-1",
        title="Example Live",
        start_at=start_at,
        venue_name="Tokyo Dome",
        source_url="https://example.com/ai",
        requires_confirmation=True,
    )

    assert deduplicate_events([ticketmaster, ai_candidate]) == [ticketmaster]


def test_search_corrects_registered_artist_typo_for_all_providers() -> None:
    class RecordingProvider:
        name = "recording"

        def __init__(self) -> None:
            self.artist_name = ""

        async def search(self, artist_name: str, country_code: str) -> list[EventResult]:
            self.artist_name = artist_name
            return []

    async def run_search() -> None:
        provider = RecordingProvider()
        async with httpx.AsyncClient() as client:
            service = EventSearchService(Settings(), client, providers=[provider])
            result = await service.search("RADWINPS", "JP")
        assert provider.artist_name == "RADWIMPS"
        assert result.artist_name == "RADWIMPS"
        assert result.warnings == ["RADWINPSをRADWIMPSとして検索しました。"]

    asyncio.run(run_search())
