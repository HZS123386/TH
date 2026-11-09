"""Minimal local value types for the extracted OpAstro aggregation functions."""
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum


class Period(str, Enum):
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"


@dataclass
class PeriodEvent:
    timestamp: datetime
    event_type: str
    body1: str | None = None
    body2: str | None = None
    sign: str | None = None
    aspect: str | None = None
    exactness: float | None = None
    narrative_priority: float = 0
    section_bias: dict[str, float] = field(default_factory=dict)
    description: str = ""
