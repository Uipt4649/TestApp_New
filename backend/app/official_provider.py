from dataclasses import dataclass
from datetime import datetime
import hashlib
from html.parser import HTMLParser
import json
import re
from urllib.parse import quote, urljoin
from zoneinfo import ZoneInfo

import httpx

from .models import EventResult


@dataclass(frozen=True)
class OfficialSource:
    artist_name: str
    aliases: tuple[str, ...]
    url: str
    api_url: str | None = None


OFFICIAL_SOURCES = (
    OfficialSource(
        artist_name="RADWIMPS",
        aliases=("radwimps", "ラッドウィンプス"),
        url="https://radwimps.jp/yurinchi/",
    ),
    OfficialSource(
        artist_name="YOASOBI",
        aliases=("yoasobi", "ヨアソビ"),
        url="https://www.yoasobi-music.jp/news/581243",
        api_url=(
            "https://www.sonymusic.co.jp/json/v2/artist/YOASOBI/"
            "live/start/0/count/100/callback/liveCallcack"
        ),
    ),
)


def _normalized_artist_name(value: str) -> str:
    return re.sub(r"[^\w]", "", value, flags=re.UNICODE).casefold()


def _edit_distance(left: str, right: str) -> int:
    previous = list(range(len(right) + 1))
    for left_index, left_character in enumerate(left, start=1):
        current = [left_index]
        for right_index, right_character in enumerate(right, start=1):
            current.append(
                min(
                    current[-1] + 1,
                    previous[right_index] + 1,
                    previous[right_index - 1] + (left_character != right_character),
                )
            )
        previous = current
    return previous[-1]


def canonical_official_artist_name(value: str) -> str | None:
    normalized = _normalized_artist_name(value)
    if not normalized:
        return None

    exact_matches: set[str] = set()
    fuzzy_matches: set[str] = set()
    for source in OFFICIAL_SOURCES:
        for name in (source.artist_name, *source.aliases):
            candidate = _normalized_artist_name(name)
            if normalized == candidate:
                exact_matches.add(source.artist_name)
            elif min(len(normalized), len(candidate)) >= 5 and _edit_distance(
                normalized,
                candidate,
            ) <= 1:
                fuzzy_matches.add(source.artist_name)

    if len(exact_matches) == 1:
        return exact_matches.pop()
    if len(fuzzy_matches) == 1:
        return fuzzy_matches.pop()
    return None


def _parse_jsonp(value: str) -> dict:
    payload_start = value.find("(")
    payload_end = value.rfind(")")
    if payload_start < 0 or payload_end <= payload_start:
        raise ValueError("Official site returned invalid JSONP data")
    return json.loads(value[payload_start + 1 : payload_end])


class VisibleTextParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.tokens: list[str] = []
        self.title_parts: list[str] = []
        self.skip_depth = 0
        self.in_title = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"script", "style", "noscript"}:
            self.skip_depth += 1
        elif tag == "title":
            self.in_title = True

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style", "noscript"} and self.skip_depth:
            self.skip_depth -= 1
        elif tag == "title":
            self.in_title = False

    def handle_data(self, data: str) -> None:
        if self.skip_depth:
            return
        normalized = " ".join(data.split())
        if not normalized:
            return
        self.tokens.append(normalized)
        if self.in_title:
            self.title_parts.append(normalized)

    @property
    def title(self) -> str:
        return " ".join(self.title_parts).strip()


class OfficialSiteProvider:
    name = "公式サイト"

    def __init__(self, client: httpx.AsyncClient) -> None:
        self.client = client

    async def search(self, artist_name: str, country_code: str) -> list[EventResult]:
        if country_code != "JP":
            return []
        source = self._source_for(artist_name)
        if source is None:
            return []

        response = await self.client.get(
            source.api_url or source.url,
            headers={"User-Agent": "EchoMe/0.1 event-checker"},
        )
        response.raise_for_status()
        if source.api_url is not None:
            return self._parse_sony_music_schedule(response.text, source)
        return self._parse_schedule(response.text, source)

    @staticmethod
    def _source_for(artist_name: str) -> OfficialSource | None:
        canonical_name = canonical_official_artist_name(artist_name)
        if canonical_name is None:
            return None
        for source in OFFICIAL_SOURCES:
            if source.artist_name == canonical_name:
                return source
        return None

    @staticmethod
    def _parse_schedule(html: str, source: OfficialSource) -> list[EventResult]:
        parser = VisibleTextParser()
        parser.feed(html)
        title = parser.title or f"{source.artist_name} Live"
        now = datetime.now(ZoneInfo("Asia/Tokyo"))
        events: list[EventResult] = []

        for index, token in enumerate(parser.tokens):
            if not re.fullmatch(r"20\d{2}", token) or index + 1 >= len(parser.tokens):
                continue
            date_match = re.fullmatch(r"(\d{1,2})\.(\d{1,2})", parser.tokens[index + 1])
            if date_match is None:
                continue

            nearby = parser.tokens[index + 2 : index + 16]
            try:
                open_offset = nearby.index("OPEN")
                start_offset = next(
                    position
                    for position, value in enumerate(nearby)
                    if value.strip("/ ") == "START"
                )
            except ValueError:
                continue
            except StopIteration:
                continue
            if start_offset <= open_offset:
                continue
            start_time = next(
                (
                    value
                    for value in nearby[start_offset + 1 : start_offset + 4]
                    if re.fullmatch(r"\d{1,2}:\d{2}", value)
                ),
                None,
            )
            if start_time is None:
                continue
            open_time = next(
                (
                    value
                    for value in nearby[open_offset + 1 : open_offset + 4]
                    if re.fullmatch(r"\d{1,2}:\d{2}", value)
                ),
                None,
            )

            location_tokens = [
                value
                for value in nearby[:open_offset]
                if not re.fullmatch(r"\([A-Za-z]{3}\)", value)
            ]
            if not location_tokens:
                continue
            venue_name = location_tokens[-1]
            city = location_tokens[-2].title() if len(location_tokens) > 1 else None
            month, day = (int(value) for value in date_match.groups())
            hour, minute = (int(value) for value in start_time.split(":"))
            try:
                start_at = datetime(
                    int(token),
                    month,
                    day,
                    hour,
                    minute,
                    tzinfo=ZoneInfo("Asia/Tokyo"),
                )
            except ValueError:
                continue
            if start_at <= now:
                continue
            doors_at = None
            if open_time is not None:
                open_hour, open_minute = (int(value) for value in open_time.split(":"))
                doors_at = start_at.replace(hour=open_hour, minute=open_minute)

            event_hash = hashlib.sha256(
                f"{source.url}|{start_at.isoformat()}|{venue_name}".encode()
            ).hexdigest()[:24]
            events.append(
                EventResult(
                    provider="official_site",
                    provider_event_id=event_hash,
                    title=title,
                    start_at=start_at,
                    doors_at=doors_at,
                    venue_name=venue_name,
                    city=city,
                    source_url=source.url,
                    details="アーティスト公式サイト掲載情報",
                )
            )
        return events

    @staticmethod
    def _parse_sony_music_schedule(
        jsonp: str,
        source: OfficialSource,
    ) -> list[EventResult]:
        payload = _parse_jsonp(jsonp)
        now = datetime.now(ZoneInfo("Asia/Tokyo"))
        events: list[EventResult] = []

        for tour in payload.get("items", []):
            for live_item in tour.get("liveItem", []):
                date_text = str(live_item.get("date") or "")
                start_text = str(live_item.get("start") or "12:00")
                try:
                    start_at = datetime.strptime(
                        f"{date_text} {start_text}",
                        "%Y.%m.%d %H:%M",
                    ).replace(tzinfo=ZoneInfo("Asia/Tokyo"))
                except ValueError:
                    continue
                if start_at <= now:
                    continue
                doors_at = None
                open_text = str(live_item.get("open") or "")
                if re.fullmatch(r"\d{1,2}:\d{2}", open_text):
                    open_hour, open_minute = (int(value) for value in open_text.split(":"))
                    doors_at = start_at.replace(hour=open_hour, minute=open_minute)

                title = str(
                    live_item.get("tourName")
                    or tour.get("tourName")
                    or f"{source.artist_name} Live"
                ).strip()
                venue_name = str(live_item.get("place") or "").strip() or None
                area = str(live_item.get("area") or "").strip() or None
                link = str(live_item.get("link") or tour.get("link") or "").strip()
                source_url = urljoin("https://www.sonymusic.co.jp", link) or source.url
                event_hash = hashlib.sha256(
                    f"{source_url}|{start_at.isoformat()}|{venue_name}".encode()
                ).hexdigest()[:24]
                details = "Sony Music公式ライブ情報"
                if not live_item.get("start"):
                    details += "（開始時刻未掲載）"
                events.append(
                    EventResult(
                        provider="official_site",
                        provider_event_id=event_hash,
                        title=title,
                        start_at=start_at,
                        doors_at=doors_at,
                        venue_name=venue_name,
                        city=area,
                        source_url=source_url,
                        details=details,
                    )
                )
        return events


class SonyMusicProvider:
    name = "Sony Music公式"

    def __init__(self, client: httpx.AsyncClient) -> None:
        self.client = client

    async def search(self, artist_name: str, country_code: str) -> list[EventResult]:
        if country_code != "JP":
            return []
        artist = await self._resolve_artist(artist_name)
        if artist is None:
            return []

        artist_slug, official_name, artist_page = artist
        live_url = (
            "https://www.sonymusic.co.jp/json/v2/artist/"
            f"{quote(artist_slug, safe='-._~')}/live/start/0/count/500/"
            "callback/liveCallcack"
        )
        response = await self.client.get(
            live_url,
            headers={"User-Agent": "EchoMe/0.1 event-checker"},
            timeout=6.0,
        )
        response.raise_for_status()
        source = OfficialSource(
            artist_name=official_name,
            aliases=(),
            url=urljoin("https://www.sonymusic.co.jp", artist_page),
            api_url=live_url,
        )
        return OfficialSiteProvider._parse_sony_music_schedule(response.text, source)

    async def _resolve_artist(
        self,
        artist_name: str,
    ) -> tuple[str, str, str] | None:
        normalized_input = _normalized_artist_name(artist_name)
        if not normalized_input:
            return None
        search_url = (
            "https://www.sonymusic.co.jp/json/search/category/artist/"
            f"start/0/count/20/word/{quote(artist_name, safe='')}"
        )
        response = await self.client.get(
            search_url,
            headers={"User-Agent": "EchoMe/0.1 event-checker"},
            timeout=6.0,
        )
        response.raise_for_status()
        candidates = _parse_jsonp(response.text).get("items", [])

        exact_matches = [
            candidate
            for candidate in candidates
            if _normalized_artist_name(str(candidate.get("artistName") or ""))
            == normalized_input
        ]
        selected = exact_matches[0] if len(exact_matches) == 1 else None
        if selected is None and len(normalized_input) >= 5:
            fuzzy_matches = [
                candidate
                for candidate in candidates
                if _edit_distance(
                    normalized_input,
                    _normalized_artist_name(str(candidate.get("artistName") or "")),
                )
                <= 1
            ]
            if len(fuzzy_matches) == 1:
                selected = fuzzy_matches[0]
        if selected is None:
            return None

        artist_page = str(selected.get("artistPage") or "")
        slug_match = re.fullmatch(r"/artist/([^/]+)/?", artist_page)
        if slug_match is None:
            return None
        official_name = str(selected.get("artistName") or artist_name).strip()
        return slug_match.group(1), official_name, artist_page
