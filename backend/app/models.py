from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator


class ChatEventRequest(BaseModel):
    message: str = Field(min_length=1, max_length=200)
    country_code: str = Field(default="JP", min_length=2, max_length=2)

    @field_validator("message")
    @classmethod
    def normalize_message(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if not normalized:
            raise ValueError("message must not be blank")
        return normalized

    @field_validator("country_code")
    @classmethod
    def normalize_country_code(cls, value: str) -> str:
        if not value.isalpha():
            raise ValueError("country_code must contain two letters")
        return value.upper()


class EventResult(BaseModel):
    provider: Literal[
        "bandsintown",
        "ticketmaster",
        "youtube",
        "gemini_grounded",
        "official_site",
    ]
    provider_event_id: str
    title: str
    start_at: datetime
    doors_at: datetime | None = None
    venue_name: str | None = None
    address: str | None = None
    city: str | None = None
    source_url: str
    details: str | None = None
    requires_confirmation: bool = False


class ChatEventResponse(BaseModel):
    artist_name: str
    message: str
    events: list[EventResult]
    warnings: list[str] = Field(default_factory=list)


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
