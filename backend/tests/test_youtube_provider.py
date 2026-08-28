import asyncio
from datetime import datetime, timedelta, timezone

import httpx

from app.providers import YouTubeProvider


def test_youtube_provider_returns_public_upcoming_artist_broadcast() -> None:
    scheduled_start = datetime.now(timezone.utc) + timedelta(days=2)

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/search"):
            return httpx.Response(
                200,
                json={
                    "items": [
                        {
                            "id": {"videoId": "video-1"},
                            "snippet": {
                                "channelTitle": "Eve Official",
                                "liveBroadcastContent": "upcoming",
                            },
                        },
                        {
                            "id": {"videoId": "fan-video"},
                            "snippet": {
                                "channelTitle": "煌イヴ Eve Kirameki",
                                "liveBroadcastContent": "upcoming",
                            },
                        },
                    ]
                },
            )
        return httpx.Response(
            200,
            json={
                "items": [
                    {
                        "id": "video-1",
                        "snippet": {
                            "title": "Eve YouTube Live",
                            "channelTitle": "Eve Official",
                        },
                        "liveStreamingDetails": {
                            "scheduledStartTime": scheduled_start.isoformat()
                        },
                        "status": {"privacyStatus": "public"},
                    }
                ]
            },
        )

    async def run_search():
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            provider = YouTubeProvider("test-key", client)
            return await provider.search("Eve", "JP")

    events = asyncio.run(run_search())

    assert len(events) == 1
    assert events[0].provider == "youtube"
    assert events[0].provider_event_id == "video-1"
    assert events[0].venue_name == "YouTube"


def test_youtube_provider_uses_cache_for_same_artist() -> None:
    request_count = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal request_count
        request_count += 1
        return httpx.Response(200, json={"items": []})

    async def run_searches() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            provider = YouTubeProvider("test-key", client)
            assert await provider.search("Eve", "JP") == []
            assert await provider.search("Eve", "JP") == []

    asyncio.run(run_searches())

    assert request_count == 1
