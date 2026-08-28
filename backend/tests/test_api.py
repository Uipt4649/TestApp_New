from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.service import SearchResult


class FakeSearchService:
    async def search(self, message: str, country_code: str) -> SearchResult:
        return SearchResult(artist_name=message, events=[], warnings=[])


def test_chat_endpoint_requires_token() -> None:
    app = create_app(
        Settings(app_token="a" * 32, allow_loopback_without_token=False)
    )
    with TestClient(app) as client:
        response = client.post("/v1/chat/events", json={"message": "あいみょん"})
    assert response.status_code == 401


def test_chat_endpoint_returns_structured_response() -> None:
    app = create_app(
        Settings(app_token="a" * 32, allow_loopback_without_token=False)
    )
    with TestClient(app) as client:
        app.state.search_service = FakeSearchService()
        response = client.post(
            "/v1/chat/events",
            headers={"X-App-Token": "a" * 32},
            json={"message": "あいみょん"},
        )
    assert response.status_code == 200
    assert response.json()["artist_name"] == "あいみょん"


def test_loopback_client_can_use_local_backend_without_token() -> None:
    app = create_app(Settings())
    with TestClient(app, client=("127.0.0.1", 50000)) as client:
        app.state.search_service = FakeSearchService()
        response = client.post("/v1/chat/events", json={"message": "あいみょん"})
    assert response.status_code == 200
