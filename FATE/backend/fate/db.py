from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, create_engine
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker

from .config import settings


class Base(DeclarativeBase):
    pass


class Visit(Base):
    __tablename__ = "visits"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    source: Mapped[str] = mapped_column(String(64))
    campaign: Mapped[str] = mapped_column(String(64))
    visited_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Reading(Base):
    __tablename__ = "readings"
    __table_args__ = (Index("ix_readings_queue", "status", "available_at"),)

    token_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    visit_id: Mapped[str | None] = mapped_column(ForeignKey("visits.id", ondelete="SET NULL"))
    status: Mapped[str] = mapped_column(String(12))
    input: Mapped[dict | None] = mapped_column(JSONB(none_as_null=True))
    result: Mapped[dict | None] = mapped_column(JSONB(none_as_null=True))
    error: Mapped[str | None] = mapped_column(String(40))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    available_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    lease_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    lease_id: Mapped[str | None] = mapped_column(String(32))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class RateLimit(Base):
    __tablename__ = "rate_limits"

    bucket: Mapped[str] = mapped_column(String(64), primary_key=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    count: Mapped[int] = mapped_column(Integer)


engine = create_engine(settings.database_url, pool_pre_ping=True, pool_size=5, max_overflow=5)
Session = sessionmaker(engine, expire_on_commit=False)
