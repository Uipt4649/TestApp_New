from dataclasses import dataclass
import os
from pathlib import Path


def _optional_environment_value(name: str) -> str | None:
    value = os.getenv(name, "").strip()
    return value or None


@dataclass(frozen=True)
class Settings:
    app_token: str | None = None
    allow_loopback_without_token: bool = True
    ticketmaster_api_key: str | None = None
    bandsintown_app_id: str | None = None
    youtube_api_key: str | None = None
    youtube_cache_ttl_seconds: int = 86_400
    youtube_daily_search_limit: int = 80
    gemini_api_key: str | None = None
    gemini_model: str = "gemini-3.1-flash-lite"
    gemini_artist_extraction_enabled: bool = False
    gemini_grounded_search_enabled: bool = False
    gemini_grounded_model: str = "gemini-3.1-flash-lite"
    gemini_monthly_grounded_request_limit: int = 400
    gemini_usage_database_path: str = str(
        Path(__file__).resolve().parents[1] / "data" / "usage.sqlite3"
    )
    request_timeout_seconds: float = 12.0
    cache_ttl_seconds: int = 21_600
    rate_limit_requests: int = 30
    rate_limit_window_seconds: int = 60

    @classmethod
    def from_environment(cls) -> "Settings":
        app_token = _optional_environment_value("BACKEND_APP_TOKEN")
        allow_loopback_without_token = os.getenv(
            "ALLOW_LOOPBACK_WITHOUT_TOKEN",
            "true",
        ).lower() in {"1", "true", "yes"}
        if app_token is not None and len(app_token) < 32:
            raise RuntimeError(
                "BACKEND_APP_TOKEN must be set to a random value of at least 32 characters."
            )
        if app_token is None and not allow_loopback_without_token:
            raise RuntimeError(
                "BACKEND_APP_TOKEN is required when loopback access without a token is disabled."
            )

        return cls(
            app_token=app_token,
            allow_loopback_without_token=allow_loopback_without_token,
            ticketmaster_api_key=_optional_environment_value("TICKETMASTER_API_KEY"),
            bandsintown_app_id=_optional_environment_value("BANDSINTOWN_APP_ID"),
            youtube_api_key=_optional_environment_value("YOUTUBE_API_KEY"),
            youtube_cache_ttl_seconds=int(
                os.getenv("YOUTUBE_CACHE_TTL_SECONDS", "86400")
            ),
            youtube_daily_search_limit=int(
                os.getenv("YOUTUBE_DAILY_SEARCH_LIMIT", "80")
            ),
            gemini_api_key=_optional_environment_value("GEMINI_API_KEY"),
            gemini_model=os.getenv("GEMINI_MODEL", "gemini-3.1-flash-lite").strip(),
            gemini_artist_extraction_enabled=os.getenv(
                "GEMINI_ARTIST_EXTRACTION_ENABLED",
                "false",
            ).lower() in {"1", "true", "yes"},
            gemini_grounded_search_enabled=os.getenv(
                "GEMINI_GROUNDED_SEARCH_ENABLED",
                "false",
            ).lower() in {"1", "true", "yes"},
            gemini_grounded_model=os.getenv(
                "GEMINI_GROUNDED_MODEL",
                "gemini-3.1-flash-lite",
            ).strip(),
            gemini_monthly_grounded_request_limit=min(
                int(os.getenv("GEMINI_MONTHLY_GROUNDED_REQUEST_LIMIT", "400")),
                400,
            ),
            gemini_usage_database_path=os.getenv(
                "GEMINI_USAGE_DATABASE_PATH",
                str(Path(__file__).resolve().parents[1] / "data" / "usage.sqlite3"),
            ).strip(),
            request_timeout_seconds=float(os.getenv("REQUEST_TIMEOUT_SECONDS", "12")),
            cache_ttl_seconds=int(os.getenv("CACHE_TTL_SECONDS", "21600")),
            rate_limit_requests=int(os.getenv("RATE_LIMIT_REQUESTS", "30")),
            rate_limit_window_seconds=int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60")),
        )
