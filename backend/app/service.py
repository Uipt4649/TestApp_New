import asyncio
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import json
import re
from typing import Protocol
from urllib.parse import quote

import httpx

from .config import Settings
from .grounded_provider import GeminiGroundedEventProvider
from .models import EventResult
from .official_provider import (
    OfficialSiteProvider,
    SonyMusicProvider,
    canonical_official_artist_name,
)
from .providers import BandsintownProvider, TicketmasterProvider, YouTubeProvider
from .usage import MonthlyUsageLedger


class EventProvider(Protocol):
    name: str

    async def search(self, artist_name: str, country_code: str) -> list[EventResult]: ...


class ArtistNameExtractor(Protocol):
    async def extract(self, message: str) -> str: ...


class GeminiArtistNameExtractor:
    def __init__(self, api_key: str, model: str, client: httpx.AsyncClient) -> None:
        self.api_key = api_key
        self.model = model
        self.client = client

    async def extract(self, message: str) -> str:
        encoded_model = quote(self.model, safe="-._")
        response = await self.client.post(
            f"https://generativelanguage.googleapis.com/v1beta/models/{encoded_model}:generateContent",
            headers={"x-goog-api-key": self.api_key},
            json={
                "system_instruction": {
                    "parts": [
                        {
                            "text": (
                                "Extract only the artist, idol, band, actor, or creator name "
                                "whose future schedule the user wants. Never invent a name."
                            )
                        }
                    ]
                },
                "contents": [{"role": "user", "parts": [{"text": message}]}],
                "generationConfig": {
                    "temperature": 0,
                    "responseMimeType": "application/json",
                    "responseSchema": {
                        "type": "OBJECT",
                        "properties": {"artist_name": {"type": "STRING"}},
                        "required": ["artist_name"],
                    },
                },
            },
        )
        response.raise_for_status()
        candidates = response.json().get("candidates", [])
        text = candidates[0]["content"]["parts"][0]["text"]
        artist_name = str(json.loads(text)["artist_name"]).strip()
        if not artist_name or len(artist_name) > 100:
            raise ValueError("Gemini returned an invalid artist name")
        return artist_name


@dataclass
class SearchResult:
    artist_name: str
    events: list[EventResult]
    warnings: list[str]


@dataclass
class CacheEntry:
    expires_at: datetime
    result: SearchResult


def fallback_artist_name(message: str) -> str:
    artist_name = message.strip().strip("「」『』\"'")
    suffixes = (
        "の今後の予定を調べて",
        "のライブ情報を調べて",
        "の予定を調べて",
        "のライブ情報",
        "の今後の予定",
        "の予定",
        "について調べて",
    )
    for suffix in suffixes:
        if artist_name.endswith(suffix):
            artist_name = artist_name[: -len(suffix)].strip()
            break
    return artist_name[:100]


def deduplicate_events(events: list[EventResult]) -> list[EventResult]:
    unique: dict[tuple[str, str, str], EventResult] = {}
    provider_priority = {
        "gemini_grounded": 0,
        "ticketmaster": 2,
        "youtube": 2,
        "bandsintown": 3,
        "official_site": 4,
    }
    for event in sorted(events, key=lambda item: item.start_at):
        normalized_title = re.sub(r"\W+", "", event.title).casefold()
        normalized_venue = re.sub(r"\W+", "", event.venue_name or "").casefold()
        key = (event.start_at.date().isoformat(), normalized_title, normalized_venue)
        existing = unique.get(key)
        if existing is None or provider_priority[event.provider] > provider_priority[existing.provider]:
            unique[key] = event
    return list(unique.values())


class EventSearchService:
    def __init__(
        self,
        settings: Settings,
        client: httpx.AsyncClient,
        providers: list[EventProvider] | None = None,
        artist_name_extractor: ArtistNameExtractor | None = None,
    ) -> None:
        if providers is None:
            providers = [OfficialSiteProvider(client), SonyMusicProvider(client)]
            if settings.bandsintown_app_id:
                providers.append(BandsintownProvider(settings.bandsintown_app_id, client))
            if settings.ticketmaster_api_key:
                providers.append(TicketmasterProvider(settings.ticketmaster_api_key, client))
            if settings.youtube_api_key:
                providers.append(
                    YouTubeProvider(
                        settings.youtube_api_key,
                        client,
                        cache_ttl_seconds=settings.youtube_cache_ttl_seconds,
                        daily_search_limit=settings.youtube_daily_search_limit,
                    )
                )
            if settings.gemini_api_key and settings.gemini_grounded_search_enabled:
                providers.append(
                    GeminiGroundedEventProvider(
                        settings.gemini_api_key,
                        settings.gemini_grounded_model,
                        client,
                        MonthlyUsageLedger(settings.gemini_usage_database_path),
                        settings.gemini_monthly_grounded_request_limit,
                    )
                )
        self.providers = providers
        self.artist_name_extractor = artist_name_extractor
        if (
            self.artist_name_extractor is None
            and settings.gemini_api_key
            and settings.gemini_artist_extraction_enabled
        ):
            self.artist_name_extractor = GeminiArtistNameExtractor(
                settings.gemini_api_key,
                settings.gemini_model,
                client,
            )
        self.cache_ttl = timedelta(seconds=settings.cache_ttl_seconds)
        self.cache: dict[tuple[str, str], CacheEntry] = {}

    async def search(self, message: str, country_code: str) -> SearchResult:
        artist_name = fallback_artist_name(message)
        extraction_warning: str | None = None
        correction_warning: str | None = None
        if self.artist_name_extractor is not None:
            try:
                artist_name = await self.artist_name_extractor.extract(message)
            except Exception:
                extraction_warning = "AIによる名前の抽出に失敗したため、入力内容で検索しました。"
        canonical_name = canonical_official_artist_name(artist_name)
        if canonical_name is not None and canonical_name != artist_name:
            correction_warning = f"{artist_name}を{canonical_name}として検索しました。"
            artist_name = canonical_name
        cache_key = (artist_name.casefold(), country_code)
        now = datetime.now(timezone.utc)
        cached = self.cache.get(cache_key)
        if cached and cached.expires_at > now:
            return cached.result

        if not self.providers:
            warnings = ["イベントAPIが設定されていません。"]
            if correction_warning:
                warnings.insert(0, correction_warning)
            if extraction_warning:
                warnings.insert(0, extraction_warning)
            return SearchResult(
                artist_name=artist_name,
                events=[],
                warnings=warnings,
            )

        responses = await asyncio.gather(
            *(provider.search(artist_name, country_code) for provider in self.providers),
            return_exceptions=True,
        )
        events: list[EventResult] = []
        warnings = [
            warning
            for warning in (extraction_warning, correction_warning)
            if warning is not None
        ]
        for provider, response in zip(self.providers, responses, strict=True):
            if isinstance(response, Exception):
                warnings.append(f"{provider.name}から情報を取得できませんでした。")
            else:
                events.extend(response)

        result = SearchResult(
            artist_name=artist_name,
            events=deduplicate_events(events),
            warnings=warnings,
        )
        self.cache[cache_key] = CacheEntry(expires_at=now + self.cache_ttl, result=result)
        return result
