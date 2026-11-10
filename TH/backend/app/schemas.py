from datetime import date, datetime
from typing import Annotated, Literal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

LanguageCode = Literal["zh", "th", "vi", "en"]


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class ProfileInput(Input):
    display_name: str = Field(default="", max_length=60)
    gender: Literal["female", "male"] | None = None
    birth_date: date
    birth_time: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    timezone: str = "Asia/Bangkok"
    birthplace: str = Field(default="", max_length=100)
    language: LanguageCode = "zh"
    country_code: str | None = Field(default=None, pattern=r"^[A-Z]{2}$")
    location_id: str | None = Field(default=None, pattern=r"^geonames:[1-9][0-9]{0,10}$")
    latitude: float | None = Field(default=None, ge=-90, le=90, allow_inf_nan=False)
    longitude: float | None = Field(default=None, ge=-180, le=180, allow_inf_nan=False)

    @field_validator("timezone")
    @classmethod
    def valid_timezone(cls, value):
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError):
            raise ValueError("timezone_invalid") from None
        return value

    @model_validator(mode="after")
    def valid_date(self):
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("validation_failed")
        if not 1901 <= self.birth_date.year <= 2099:
            raise ValueError("date_range")
        if self.birth_date > datetime.now(ZoneInfo(self.timezone)).date():
            raise ValueError("future_birthdate")
        return self


class ChatInput(Input):
    message: str = Field(min_length=1, max_length=2000)
    provider: Literal["mock", "openai", "deepseek", "qwen", "kimi", "companion"] = "mock"
    context: str = Field(default="", max_length=1500)
    period: Literal["today", "week", "month"] | None = None


class FortuneInput(Input):
    profile: ProfileInput
    period: Literal["today", "week", "month"] = "today"


class FortuneNarrativeInput(FortuneInput):
    for_date: date


class BaziTestInput(Input):
    profile: ProfileInput
    source: Literal["compare", "github", "roxy"] = "compare"
    topics: list[Literal["chart", "strength", "luck", "annual"]] = Field(default_factory=lambda: ["chart"], min_length=1, max_length=4)
    clock: Literal["local", "beijing"] = "local"
    focus: Literal["overview", "work", "love", "money", "family"] = "overview"
    gender: Literal["male", "female"] | None = None
    year: int = Field(default_factory=lambda: datetime.now(ZoneInfo("Asia/Bangkok")).year, ge=1901, le=2100)

    @model_validator(mode="after")
    def valid_selection(self):
        if len(set(self.topics)) != len(self.topics):
            raise ValueError("validation_failed")
        if self.source != "github" and "luck" in self.topics and self.gender is None:
            raise ValueError("bazi_gender_required")
        return self


class ThaiReadingInput(Input):
    profile: ProfileInput
    reading: Literal["overview", "annual", "money", "love", "work", "family"] = "overview"
    year: int = Field(default_factory=lambda: datetime.now(ZoneInfo("Asia/Bangkok")).year, ge=1901, le=2100)


ConcernCode = Literal[
    "money_pressure", "work_change", "relationship_unclear", "study_exam", "business_slow", "family_load", "breakup", "single", "stress", "confidence"
]


class JourneyRecord(Input):
    concern: ConcernCode
    day: date
    feedback: Literal["good", "ordinary", "hard"]


class TasteInput(Input):
    style: Literal["any", "warm", "soft", "cool"] = "any"
    category: Literal["all", "bracelet", "crystal", "charm"] = "all"
    budget: Literal[300, 500, 1000] = 1000


class DemoOrderInput(Input):
    id: str = Field(pattern=r"^[a-zA-Z0-9-]{1,64}$")
    product: Literal["moon", "rose", "amber", "purple", "star", "crystal"]
    size: Literal["14 cm", "16 cm", "18 cm", "standard"]
    quantity: int = Field(ge=1, le=9)
    total: int = Field(gt=0, le=100000)
    day: date


class CompanionInput(Input):
    taste: TasteInput = Field(default_factory=TasteInput)
    demo_orders: list[DemoOrderInput] = Field(default_factory=list, max_length=20)
    concern: ConcernCode | None = None
    option: Literal["a", "b"] | None = None
    topic: Literal["love", "money", "family", "work"] = "love"
    period: Literal["today", "week", "month"] = "today"
    mood: Literal["steady", "ready", "tired"] = "steady"
    frequency: Literal["daily", "weekly", "off"] = "off"
    routine: Literal["day", "late"] = "day"
    reminder_time: str = Field(default="09:00", pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    wish: str = Field(default="", max_length=1000)
    favorites: list[Literal["moon", "rose", "amber", "purple", "star", "crystal"]] = Field(default_factory=list, max_length=6)
    demo_unlocks: list[Literal["solution", "life"]] = Field(default_factory=list, max_length=2)
    records: list[JourneyRecord] = Field(default_factory=list, max_length=70)
    paused: bool = False
    helpful: bool | None = None
    large_text: bool = False
    checks: list[Annotated[str, Field(pattern=r"^\d{4}-\d{2}-\d{2}:[a-z_]{1,30}:[0-2]$")]] = Field(default_factory=list, max_length=210)

    @model_validator(mode="after")
    def valid_records(self):
        if len({row.id for row in self.demo_orders}) != len(self.demo_orders) or any(
            row.day > datetime.now(ZoneInfo("Asia/Bangkok")).date() for row in self.demo_orders
        ):
            raise ValueError("validation_failed")
        keys = [(row.concern, row.day) for row in self.records]
        if len(set(keys)) != len(keys) or any(row.day > datetime.now(ZoneInfo("Asia/Bangkok")).date() for row in self.records):
            raise ValueError("validation_failed")
        if any(sum(row.concern == code for row in self.records) > 7 for code in set(row.concern for row in self.records)):
            raise ValueError("validation_failed")
        return self


class MemoryInput(Input):
    content: str = Field(min_length=1, max_length=500)


class LanguageInput(Input):
    language: LanguageCode


class AccountInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    username: str = Field(min_length=3, max_length=32, pattern=r"^[a-zA-Z0-9_]+$")
    password: str = Field(min_length=8, max_length=128)

    @field_validator("username")
    @classmethod
    def normalize_username(cls, value):
        return value.lower()
