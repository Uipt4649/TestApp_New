import asyncio
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
import re
from urllib.parse import quote

import httpx

from .models import EventResult


def _parse_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def _normalized_name(value: str) -> str:
    return re.sub(r"[^\w]", "", value, flags=re.UNICODE).casefold()


def _channel_matches_artist(artist_name: str, channel_title: str) -> bool:
    artist = _normalized_name(artist_name)
    channel = _normalized_name(channel_title)
    if not artist or not channel:
        return False
    if artist == channel:
        return True
    trusted_suffixes = {
        "ch",
        "channel",
        "music",
        "mv",
        "official",
        "officialch",
        "officialchannel",
        "officialmusic",
    }
    if channel.startswith(artist):
        return channel[len(artist) :] in trusted_suffixes
    if channel.endswith(artist):
        return channel[: -len(artist)] in trusted_suffixes
    return False


@dataclass
class YouTubeCacheEntry:
    expires_at: datetime
    events: list[EventResult]


class YouTubeDailyLimitReached(RuntimeError):
    pass


class YouTubeProvider:
    name = "youtube"

    def __init__(
        self,
        api_key: str,
        client: httpx.AsyncClient,
        cache_ttl_seconds: int = 86_400,
        daily_search_limit: int = 80,
    ) -> None:
        self.api_key = api_key
        self.client = client
        self.cache_ttl = timedelta(seconds=max(cache_ttl_seconds, 3_600))
        self.daily_search_limit = max(1, min(daily_search_limit, 80))
        self.cache: dict[tuple[str, str], YouTubeCacheEntry] = {}
        self.search_day = date.today()
        self.search_count = 0
        self.search_lock = asyncio.Lock()

    async def search(self, artist_name: str, country_code: str) -> list[EventResult]:
        cache_key = (artist_name.casefold(), country_code)
        now = datetime.now(timezone.utc)
        cached = self.cache.get(cache_key)
        if cached and cached.expires_at > now:
            return cached.events

        async with self.search_lock:
            today = date.today()
            if self.search_day != today:
                self.search_day = today
                self.search_count = 0
            if self.search_count >= self.daily_search_limit:
                raise YouTubeDailyLimitReached("YouTube daily search safety limit reached")
            self.search_count += 1

        search_response = await self.client.get(
            "https://www.googleapis.com/youtube/v3/search",
            params={
                "key": self.api_key,
                "part": "snippet",
                "q": artist_name,
                "type": "video",
                "eventType": "upcoming",
                "maxResults": 10,
                "regionCode": country_code,
                "relevanceLanguage": "ja" if country_code == "JP" else "en",
                "safeSearch": "strict",
            },
        )
        search_response.raise_for_status()

        candidates: dict[str, dict] = {}
        for item in search_response.json().get("items", []):
            video_id = item.get("id", {}).get("videoId")
            snippet = item.get("snippet", {})
            channel_title = str(snippet.get("channelTitle") or "")
            if (
                video_id
                and snippet.get("liveBroadcastContent") == "upcoming"
                and _channel_matches_artist(artist_name, channel_title)
            ):
                candidates[str(video_id)] = snippet

        if not candidates:
            events: list[EventResult] = []
        else:
            events = await self._load_scheduled_broadcasts(candidates)

        self.cache[cache_key] = YouTubeCacheEntry(
            expires_at=now + self.cache_ttl,
            events=events,
        )
        return events

    async def _load_scheduled_broadcasts(
        self,
        candidates: dict[str, dict],
    ) -> list[EventResult]:
        response = await self.client.get(
            "https://www.googleapis.com/youtube/v3/videos",
            params={
                "key": self.api_key,
                "part": "snippet,liveStreamingDetails,status",
                "id": ",".join(candidates),
            },
        )
        response.raise_for_status()

        events: list[EventResult] = []
        for item in response.json().get("items", []):
            video_id = str(item.get("id") or "")
            snippet = item.get("snippet", {})
            status = item.get("status", {})
            scheduled_start = _parse_datetime(
                item.get("liveStreamingDetails", {}).get("scheduledStartTime")
            )
            if (
                not video_id
                or not scheduled_start
                or scheduled_start <= datetime.now(timezone.utc)
                or status.get("privacyStatus") != "public"
            ):
                continue

            channel_title = str(snippet.get("channelTitle") or "")
            events.append(
                EventResult(
                    provider="youtube",
                    provider_event_id=video_id,
                    title=str(snippet.get("title") or "YouTube Live"),
                    start_at=scheduled_start,
                    venue_name="YouTube",
                    source_url=f"https://www.youtube.com/watch?v={video_id}",
                    details=f"YouTube予定配信 / チャンネル: {channel_title}",
                )
            )
        return events


class BandsintownProvider:
    name = "bandsintown"

    def __init__(self, app_id: str, client: httpx.AsyncClient) -> None:
        self.app_id = app_id
        self.client = client

    async def search(self, artist_name: str, country_code: str) -> list[EventResult]:
        encoded_artist = quote(artist_name, safe="")
        response = await self.client.get(
            f"https://rest.bandsintown.com/artists/{encoded_artist}/events",
            params={"app_id": self.app_id, "date": "upcoming"},
        )
        response.raise_for_status()

        payload = response.json()
        if not isinstance(payload, list):
            return []

        events: list[EventResult] = []
        for item in payload:
            venue = item.get("venue") or {}
            event_country = str(venue.get("country") or "").upper()
            if event_country and len(event_country) == 2 and event_country != country_code:
                continue

            start_at = _parse_datetime(item.get("datetime"))
            source_url = item.get("url")
            event_id = item.get("id")
            if not start_at or not source_url or event_id is None:
                continue

            events.append(
                EventResult(
                    provider="bandsintown",
                    provider_event_id=str(event_id),
                    title=item.get("title") or f"{artist_name} Live",
                    start_at=start_at,
                    venue_name=venue.get("name"),
                    address=venue.get("street_address"),
                    city=venue.get("city"),
                    source_url=source_url,
                    details=item.get("description"),
                )
            )
        return events


class TicketmasterProvider:
    name = "ticketmaster"

    def __init__(self, api_key: str, client: httpx.AsyncClient) -> None:
        self.api_key = api_key
        self.client = client

    async def search(self, artist_name: str, country_code: str) -> list[EventResult]:
        response = await self.client.get(
            "https://app.ticketmaster.com/discovery/v2/events.json",
            params={
                "apikey": self.api_key,
                "keyword": artist_name,
                "countryCode": country_code,
                "classificationName": "music",
                "sort": "date,asc",
                "size": 50,
            },
        )
        response.raise_for_status()

        items = response.json().get("_embedded", {}).get("events", [])
        events: list[EventResult] = []
        for item in items:
            dates = item.get("dates", {}).get("start", {})
            start_at = _parse_datetime(dates.get("dateTime"))
            if start_at is None and dates.get("localDate"):
                local_time = dates.get("localTime") or time.min.isoformat()
                start_at = _parse_datetime(f"{dates['localDate']}T{local_time}")

            venues = item.get("_embedded", {}).get("venues", [])
            venue = venues[0] if venues else {}
            source_url = item.get("url")
            event_id = item.get("id")
            if not start_at or not source_url or not event_id:
                continue

            address_parts = [
                venue.get("address", {}).get("line1"),
                venue.get("postalCode"),
            ]
            events.append(
                EventResult(
                    provider="ticketmaster",
                    provider_event_id=str(event_id),
                    title=item.get("name") or f"{artist_name} Live",
                    start_at=start_at,
                    venue_name=venue.get("name"),
                    address=" ".join(part for part in address_parts if part) or None,
                    city=venue.get("city", {}).get("name"),
                    source_url=source_url,
                    details=item.get("info") or item.get("pleaseNote"),
                )
            )
        return events
