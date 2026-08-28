from datetime import datetime, timedelta, timezone
import hashlib
import json
from urllib.parse import quote, urlparse

import httpx

from .models import EventResult
from .providers import _parse_datetime
from .usage import MonthlyUsageLedger


class GroundedSearchLimitReached(RuntimeError):
    pass


class GeminiGroundedEventProvider:
    name = "AI検索"

    def __init__(
        self,
        api_key: str,
        model: str,
        client: httpx.AsyncClient,
        usage_ledger: MonthlyUsageLedger,
        monthly_request_limit: int,
    ) -> None:
        self.api_key = api_key
        self.model = model
        self.client = client
        self.usage_ledger = usage_ledger
        self.monthly_request_limit = max(1, min(monthly_request_limit, 400))

    async def search(self, artist_name: str, country_code: str) -> list[EventResult]:
        if not self.usage_ledger.reserve("gemini_grounded", self.monthly_request_limit):
            raise GroundedSearchLimitReached("Monthly grounded search limit reached")

        now = datetime.now(timezone.utc)
        encoded_model = quote(self.model, safe="-._")
        response = await self.client.post(
            f"https://generativelanguage.googleapis.com/v1beta/models/{encoded_model}:generateContent",
            headers={"x-goog-api-key": self.api_key},
            json={
                "contents": [
                    {
                        "role": "user",
                        "parts": [
                            {
                                "text": (
                                    f"Today is {now.date().isoformat()}. Find confirmed future live "
                                    f"concerts or tours for {artist_name} in country {country_code}. "
                                    "Prefer the artist's official site, agency, venue, or authorized "
                                    "ticket seller. Exclude rumors, past events, canceled events, "
                                    "fan posts, and events without a specific date. Return at most "
                                    "20 performances. Every event must include the supporting HTTPS "
                                    "source URL found through Google Search. Never invent missing data."
                                )
                            }
                        ],
                    }
                ],
                "tools": [{"google_search": {}}],
                "generationConfig": {
                    "temperature": 0,
                    "responseMimeType": "application/json",
                    "responseSchema": {
                        "type": "OBJECT",
                        "properties": {
                            "events": {
                                "type": "ARRAY",
                                "maxItems": 20,
                                "items": {
                                    "type": "OBJECT",
                                    "properties": {
                                        "title": {"type": "STRING"},
                                        "start_at": {"type": "STRING"},
                                        "venue_name": {"type": "STRING"},
                                        "address": {"type": "STRING"},
                                        "city": {"type": "STRING"},
                                        "source_url": {"type": "STRING"},
                                    },
                                    "required": ["title", "start_at", "source_url"],
                                },
                            }
                        },
                        "required": ["events"],
                    },
                },
            },
        )
        response.raise_for_status()
        return self._validated_events(response.json(), now)

    def _validated_events(self, payload: dict, now: datetime) -> list[EventResult]:
        candidates = payload.get("candidates") or []
        if not candidates:
            return []
        candidate = candidates[0]
        citations = self._citation_urls(candidate)
        if not citations:
            return []

        parts = candidate.get("content", {}).get("parts", [])
        text = "".join(str(part.get("text") or "") for part in parts)
        try:
            raw_events = json.loads(text).get("events", [])
        except (AttributeError, json.JSONDecodeError):
            return []

        latest_allowed = now + timedelta(days=730)
        events: list[EventResult] = []
        for item in raw_events:
            source_url = str(item.get("source_url") or "").strip()
            parsed_url = urlparse(source_url)
            start_at = _parse_datetime(item.get("start_at"))
            if (
                parsed_url.scheme != "https"
                or not parsed_url.netloc
                or start_at is None
                or start_at <= now
                or start_at > latest_allowed
            ):
                continue

            source_is_cited = source_url in citations
            if not source_is_cited and not any(
                urlparse(citation).netloc == parsed_url.netloc for citation in citations
            ):
                continue

            title = str(item.get("title") or "").strip()
            if not title:
                continue
            event_hash = hashlib.sha256(
                f"{source_url}|{start_at.isoformat()}|{title}".encode()
            ).hexdigest()[:24]
            events.append(
                EventResult(
                    provider="gemini_grounded",
                    provider_event_id=event_hash,
                    title=title,
                    start_at=start_at,
                    venue_name=str(item.get("venue_name") or "").strip() or None,
                    address=str(item.get("address") or "").strip() or None,
                    city=str(item.get("city") or "").strip() or None,
                    source_url=source_url,
                    details="AI検索候補です。出典ページを確認してから登録してください。",
                    requires_confirmation=True,
                )
            )
        return events

    @staticmethod
    def _citation_urls(candidate: dict) -> set[str]:
        chunks = candidate.get("groundingMetadata", {}).get("groundingChunks", [])
        return {
            str(chunk.get("web", {}).get("uri"))
            for chunk in chunks
            if str(chunk.get("web", {}).get("uri") or "").startswith("https://")
        }
