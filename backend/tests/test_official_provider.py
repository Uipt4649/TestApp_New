import asyncio
from datetime import datetime
from zoneinfo import ZoneInfo

import httpx

from app.official_provider import OFFICIAL_SOURCES, OfficialSiteProvider, SonyMusicProvider


def test_radwimps_official_schedule_parses_future_performances(monkeypatch) -> None:
    class FixedDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            return cls(2026, 8, 27, 12, 0, tzinfo=tz)

    monkeypatch.setattr("app.official_provider.datetime", FixedDateTime)
    html = """
    <html>
      <head><title>RADWIMPS Official Fan Club Tour 2026 “ユーリンチー”</title></head>
      <body>
        <section>2026 <span>11.10</span> <span>(Tue)</span> YOKOHAMA
          <h3>ぴあアリーナMM</h3> OPEN <b>18:00</b> / START <b>19:00</b>
        </section>
        <section>2026 <span>11.11</span> <span>(Wed)</span> YOKOHAMA
          <h3>ぴあアリーナMM</h3> OPEN <b>18:00</b> / START <b>19:00</b>
        </section>
      </body>
    </html>
    """

    events = OfficialSiteProvider._parse_schedule(html, OFFICIAL_SOURCES[0])

    assert len(events) == 2
    assert events[0].provider == "official_site"
    assert events[0].venue_name == "ぴあアリーナMM"
    assert events[0].start_at == datetime(
        2026, 11, 10, 19, 0, tzinfo=ZoneInfo("Asia/Tokyo")
    )


def test_official_source_matches_radwimps_alias() -> None:
    assert OfficialSiteProvider._source_for("RADWIMPS") == OFFICIAL_SOURCES[0]
    assert OfficialSiteProvider._source_for("ラッドウィンプス") == OFFICIAL_SOURCES[0]
    assert OfficialSiteProvider._source_for("RADWINPS") == OFFICIAL_SOURCES[0]
    assert OfficialSiteProvider._source_for("Different Artist") is None


def test_yoasobi_sony_music_schedule_parses_future_performances(monkeypatch) -> None:
    class FixedDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            return cls(2026, 8, 28, 12, 0, tzinfo=tz)

    monkeypatch.setattr("app.official_provider.datetime", FixedDateTime)
    source = next(item for item in OFFICIAL_SOURCES if item.artist_name == "YOASOBI")
    jsonp = """liveCallcack({"items":[{"tourName":"YOASOBI TOUR","link":"/PR/YOASOBI/live/54776","liveItem":[{"date":"2026.10.24","area":"大阪府","place":"京セラドーム大阪","open":"15:30","start":"18:00"},{"date":"2026.12.05","area":"東京都","place":"東京ドーム","open":"15:30","start":"18:00"}]}]})"""

    events = OfficialSiteProvider._parse_sony_music_schedule(jsonp, source)

    assert len(events) == 2
    assert events[0].title == "YOASOBI TOUR"
    assert events[0].venue_name == "京セラドーム大阪"
    assert events[0].start_at == datetime(
        2026, 10, 24, 18, 0, tzinfo=ZoneInfo("Asia/Tokyo")
    )
    assert events[0].source_url == "https://www.sonymusic.co.jp/PR/YOASOBI/live/54776"


def test_sony_music_provider_resolves_artist_and_fetches_live(monkeypatch) -> None:
    class FixedDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            return cls(2026, 8, 28, 12, 0, tzinfo=tz)

    monkeypatch.setattr("app.official_provider.datetime", FixedDateTime)

    def handler(request: httpx.Request) -> httpx.Response:
        if "/json/search/category/artist/" in request.url.path:
            return httpx.Response(
                200,
                text='callback({"items":[{"artistId":70007781,"artistName":"緑黄色社会","artistPage":"/artist/ryokusyaka/"}]})',
            )
        assert request.url.path.endswith(
            "/json/v2/artist/ryokusyaka/live/start/0/count/500/callback/liveCallcack"
        )
        return httpx.Response(
            200,
            text='liveCallcack({"items":[{"tourName":"ARENA TOUR","link":"/artist/ryokusyaka/live/123","liveItem":[{"date":"2026.09.19","area":"千葉県","place":"LaLa arena TOKYO-BAY","open":"17:00","start":"18:00"}]}]})',
        )

    async def run_search() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            events = await SonyMusicProvider(client).search("緑黄色社会", "JP")
        assert len(events) == 1
        assert events[0].title == "ARENA TOUR"
        assert events[0].venue_name == "LaLa arena TOKYO-BAY"
        assert events[0].start_at == datetime(
            2026, 9, 19, 18, 0, tzinfo=ZoneInfo("Asia/Tokyo")
        )
        assert events[0].doors_at == datetime(
            2026, 9, 19, 17, 0, tzinfo=ZoneInfo("Asia/Tokyo")
        )

    asyncio.run(run_search())
