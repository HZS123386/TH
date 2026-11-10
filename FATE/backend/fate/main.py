import hashlib
import hmac
import re
from datetime import UTC, date, datetime, time, timedelta
from pathlib import Path
from typing import Annotated
from uuid import UUID

from fastapi import FastAPI, Header, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field, StrictBool, field_validator
from sqlalchemy import select, text, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import SQLAlchemyError

from .astrology import ChartError, birth_offset
from .config import settings
from .db import RateLimit, Reading, Session, Visit
from .locations import by_id, regions, search

app = FastAPI(title="FATE", version="1.0.0", docs_url=None, redoc_url=None)
api = "/api/v1"
Auth = Annotated[str | None, Header(alias="Authorization")]
TOKEN = re.compile(r"Bearer ([a-f0-9]{64})", re.ASCII)
CAMPAIGN = r"^[A-Za-z0-9_.~-]{0,64}$"


class VisitInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: UUID
    source: str = Field(default="", pattern=CAMPAIGN)
    campaign: str = Field(default="", pattern=CAMPAIGN)


class BirthInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    birth_date: date
    birth_time: str | None = Field(default=None, pattern=r"^(?:[01][0-9]|2[0-3]):[0-5][0-9]$")
    place_id: str = Field(pattern=r"^[0-9]{1,12}$")
    consent: StrictBool
    visit_id: UUID | None = None

    @field_validator("birth_date", mode="before")
    @classmethod
    def require_date_string(cls, value: object) -> object:
        if not isinstance(value, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value):
            raise ValueError("expected calendar date")
        return value

    @field_validator("birth_date")
    @classmethod
    def validate_date(cls, day: date) -> date:
        if not date(1900, 1, 1) <= day <= datetime.now(UTC).date():
            raise ValueError("unsupported birth date")
        return day


def error(status: int, code: str):
    raise HTTPException(status, code)


@app.exception_handler(RequestValidationError)
def validation_error(_request: Request, _error: RequestValidationError):
    return JSONResponse({"detail": "invalid_input"}, status_code=422)


@app.middleware("http")
async def safe_responses(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; script-src 'self'; style-src 'self'; "
        "img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
    )
    if request.url.path.startswith(api):
        response.headers["Cache-Control"] = "no-store"
    return response


def owner_key(auth: str | None) -> str:
    match = TOKEN.fullmatch(auth or "")
    if not match:
        error(401, "reading_key_required")
    return hashlib.sha256(match[1].encode("ascii")).hexdigest()


def rate_limit(db, request: Request, action: str, now: datetime, seconds: int, maximum: int):
    client = request.client.host if request.client else "unknown"
    window = int(now.timestamp()) // seconds
    message = f"{action}:{window}:{client}".encode()
    key = hmac.new(settings.ip_hash_key.encode(), message, hashlib.sha256).hexdigest()
    stmt = insert(RateLimit).values(
        bucket=key, expires_at=now + timedelta(seconds=seconds * 2), count=1,
    ).on_conflict_do_update(
        index_elements=[RateLimit.bucket], set_={"count": RateLimit.count + 1},
        where=RateLimit.count < maximum,
    ).returning(RateLimit.count)
    if db.scalar(stmt) is None:
        raise HTTPException(429, "rate_limited", headers={"Retry-After": str(seconds - int(now.timestamp()) % seconds)})


def active_reading(db, key: str, now: datetime) -> Reading | None:
    return db.scalar(select(Reading).where(Reading.token_hash == key, Reading.expires_at > now))


def public_reading(reading: Reading) -> dict:
    return {"status": reading.status, "result": reading.result, "error": reading.error}


@app.get("/healthz")
def readiness():
    if not settings.can_calculate:
        return JSONResponse({"status": "configuration_required"}, status_code=503)
    try:
        with Session() as db:
            db.execute(text("SELECT 1 FROM readings LIMIT 1"))
    except SQLAlchemyError:
        return JSONResponse({"status": "database_unavailable"}, status_code=503)
    return {"status": "ready"}


@app.get(api + "/config")
def public_config():
    return {"support_email": settings.support_email, "calculation_available": settings.can_calculate}


@app.get(api + "/locations")
def locations(
    q: Annotated[str, Query(max_length=80)] = "",
    country: Annotated[str, Query(pattern=r"^(?:[A-Z]{2})?$")] = "",
    region: Annotated[str, Query(pattern=r"^(?:[A-Z]{2}\.[0-9A-Za-z]{1,12})?$")] = "",
):
    return [{"id": p.id, "name": p.name, "name_th": p.name_th, "name_zh": p.name_zh, "country": p.country, "timezone": p.timezone}
            for p in search(q, country, region)]


@app.get(api + "/locations/regions")
def location_regions(country: Annotated[str, Query(pattern=r"^(CN|TH)$")]):
    return regions(country)


@app.post(api + "/visits", status_code=204)
def visit(body: VisitInput, request: Request):
    if len(settings.ip_hash_key) < 32:
        error(503, "configuration_required")
    now = datetime.now(UTC)
    with Session.begin() as db:
        rate_limit(db, request, "visit", now, 60, 60)
        db.execute(insert(Visit).values(
            id=str(body.id), source=body.source, campaign=body.campaign, visited_at=now,
        ).on_conflict_do_nothing(index_elements=[Visit.id]))


@app.post(api + "/reading", status_code=202)
def create_reading(body: BirthInput, request: Request, authorization: Auth = None):
    key = owner_key(authorization)
    if not body.consent:
        error(422, "consent_required")
    if not settings.can_calculate:
        error(503, "configuration_required")
    place = by_id.get(body.place_id)
    if place is None:
        error(422, "place_required")
    if body.birth_time is not None:
        try:
            birth_offset(body.birth_date, time.fromisoformat(body.birth_time), place)
        except ChartError as exc:
            error(422, exc.code)
    now = datetime.now(UTC)
    snapshot = {
        "birth_date": body.birth_date.isoformat(), "birth_time": body.birth_time,
        "place": place.model_dump(),
    }
    with Session.begin() as db:
        previous = db.get(Reading, key)
        if previous is not None:
            if previous.expires_at <= now:
                error(404, "reading_not_found")
            return public_reading(previous)
        rate_limit(db, request, "reading", now, 600, 12)
        visitor = db.get(Visit, str(body.visit_id)) if body.visit_id else None
        db.execute(insert(Reading).values(
            token_hash=key, visit_id=visitor.id if visitor else None,
            status="queued", input=snapshot, attempts=0, available_at=now,
            expires_at=now + timedelta(hours=24),
        ).on_conflict_do_nothing(index_elements=[Reading.token_hash]))
        if visitor is not None:
            db.execute(update(Visit).where(Visit.id == visitor.id, Visit.submitted_at.is_(None))
                       .values(submitted_at=now))
        return public_reading(db.get(Reading, key))


@app.get(api + "/reading")
def read_reading(authorization: Auth = None):
    key = owner_key(authorization)
    with Session() as db:
        reading = active_reading(db, key, datetime.now(UTC))
        if reading is None:
            error(404, "reading_not_found")
        return public_reading(reading)


@app.post(api + "/reading/seen", status_code=204)
def seen(authorization: Auth = None):
    key = owner_key(authorization)
    now = datetime.now(UTC)
    with Session.begin() as db:
        reading = active_reading(db, key, now)
        if reading is None or reading.status != "ready":
            error(404, "reading_not_found")
        if reading.visit_id is not None:
            db.execute(update(Visit).where(Visit.id == reading.visit_id, Visit.seen_at.is_(None)).values(seen_at=now))


@app.delete(api + "/reading", status_code=204)
def delete_reading(authorization: Auth = None):
    key = owner_key(authorization)
    with Session.begin() as db:
        reading = db.get(Reading, key)
        if reading is not None:
            db.delete(reading)


site = Path(__file__).resolve().parents[2] / "h5" / "dist"
if site.is_dir():
    @app.get("/privacy", include_in_schema=False)
    @app.get("/support", include_in_schema=False)
    def information_page():
        return FileResponse(site / "index.html")

    app.mount("/", StaticFiles(directory=site, html=True), name="h5")
