from collections import defaultdict, deque
from contextlib import asynccontextmanager
import hmac
from ipaddress import ip_address
import time

from fastapi import Depends, FastAPI, Header, HTTPException, Request, status
import httpx

from .config import Settings
from .models import ChatEventRequest, ChatEventResponse, HealthResponse
from .service import EventSearchService


class RateLimiter:
    def __init__(self, request_limit: int, window_seconds: int) -> None:
        self.request_limit = request_limit
        self.window_seconds = window_seconds
        self.requests: dict[str, deque[float]] = defaultdict(deque)

    def check(self, client_id: str) -> bool:
        now = time.monotonic()
        timestamps = self.requests[client_id]
        while timestamps and timestamps[0] <= now - self.window_seconds:
            timestamps.popleft()
        if len(timestamps) >= self.request_limit:
            return False
        timestamps.append(now)
        return True


def create_app(settings: Settings | None = None) -> FastAPI:
    resolved_settings = settings

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        nonlocal resolved_settings
        resolved_settings = resolved_settings or Settings.from_environment()
        timeout = httpx.Timeout(resolved_settings.request_timeout_seconds)
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=False) as client:
            app.state.settings = resolved_settings
            app.state.search_service = EventSearchService(resolved_settings, client)
            app.state.rate_limiter = RateLimiter(
                resolved_settings.rate_limit_requests,
                resolved_settings.rate_limit_window_seconds,
            )
            yield

    app = FastAPI(
        title="Echo.me Chatbot API",
        version="0.1.0",
        docs_url="/docs",
        redoc_url=None,
        lifespan=lifespan,
    )

    async def require_app_token(
        request: Request,
        x_app_token: str | None = Header(default=None),
    ) -> None:
        client_id = request.client.host if request.client else "unknown"
        if not request.app.state.rate_limiter.check(client_id):
            raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Too many requests")

        try:
            is_loopback = ip_address(client_id).is_loopback
        except ValueError:
            is_loopback = False

        settings = request.app.state.settings
        if settings.allow_loopback_without_token and is_loopback:
            return

        expected_token = settings.app_token
        if (
            expected_token is None
            or not x_app_token
            or not hmac.compare_digest(x_app_token, expected_token)
        ):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unauthorized")

    @app.get("/health", response_model=HealthResponse)
    async def health() -> HealthResponse:
        return HealthResponse()

    @app.post(
        "/v1/chat/events",
        response_model=ChatEventResponse,
        dependencies=[Depends(require_app_token)],
    )
    async def find_events(payload: ChatEventRequest, request: Request) -> ChatEventResponse:
        result = await request.app.state.search_service.search(
            payload.message,
            payload.country_code,
        )
        event_count = len(result.events)
        message = (
            f"{result.artist_name}の予定を{event_count}件見つけました。"
            if event_count
            else (
                f"{result.artist_name}の公開済み予定は現在確認できませんでした。"
                "時間をおいて再検索してください。"
            )
        )
        return ChatEventResponse(
            artist_name=result.artist_name,
            message=message,
            events=result.events,
            warnings=result.warnings,
        )

    return app


app = create_app()
