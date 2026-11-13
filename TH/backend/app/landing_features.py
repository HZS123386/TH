"""JY's first-party funnel and data-use confirmation on the existing backend."""
import hashlib
import time
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, Response
from pydantic import Field, StrictBool

from .schemas import Input

NOTICE_VERSION = "h5-data-use-2"
Key = Annotated[str, Header(alias="X-Report-Key", min_length=32, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")]


def owner_for(key):
    return "life:" + hashlib.sha256(key.encode()).hexdigest()


class VisitInput(Input):
    id: UUID
    source: str = Field(default="", max_length=64, pattern=r"^[A-Za-z0-9_.~-]*$")
    campaign: str = Field(default="", max_length=64, pattern=r"^[A-Za-z0-9_.~-]*$")


class VisitEvent(Input):
    report_id: str = Field(min_length=8, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")
    event: Literal["submitted", "seen"]


class ConsentInput(Input):
    notice_version: str = Field(min_length=1, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")
    granted: StrictBool


class LandingFeatures:
    def __init__(self, store, settings, reports):
        self.store, self.settings, self.reports = store, settings, reports
        with store.connect() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS landing_visits(
                    id TEXT PRIMARY KEY, owner TEXT NOT NULL, source TEXT NOT NULL,
                    campaign TEXT NOT NULL, visited_at REAL NOT NULL,
                    submitted_at REAL, seen_at REAL
                );
                CREATE INDEX IF NOT EXISTS landing_visits_created ON landing_visits(visited_at);
                CREATE TABLE IF NOT EXISTS landing_visit_reports(
                    visit_id TEXT NOT NULL REFERENCES landing_visits(id) ON DELETE CASCADE,
                    report_id TEXT NOT NULL,
                    PRIMARY KEY(visit_id, report_id)
                );
                CREATE TABLE IF NOT EXISTS landing_consents(
                    owner TEXT NOT NULL, notice_version TEXT NOT NULL, agreed_at REAL NOT NULL,
                    PRIMARY KEY(owner, notice_version)
                );
            """)

    def visit(self, body, owner):
        now = time.time()
        with self.store.connect() as db:
            db.execute("DELETE FROM landing_visits WHERE visited_at < ?", (now - 30 * 86400,))
            db.execute("INSERT INTO landing_visits(id,owner,source,campaign,visited_at) VALUES(?,?,?,?,?) "
                       "ON CONFLICT(id) DO NOTHING", (str(body.id), owner, body.source, body.campaign, now))
            row = db.execute("SELECT owner FROM landing_visits WHERE id=?", (str(body.id),)).fetchone()
            if row["owner"] != owner:
                raise HTTPException(404, "landing_visit_not_found")

    def event(self, visit_id, body, owner):
        report = self.reports.row(body.report_id, owner)
        if body.event == "seen" and not report["preview"]:
            raise HTTPException(409, "life_preview_required")
        column = "submitted_at" if body.event == "submitted" else "seen_at"
        with self.store.connect() as db:
            visit = db.execute("SELECT 1 FROM landing_visits WHERE id=? AND owner=? AND visited_at>=?",
                               (str(visit_id), owner, time.time() - 30 * 86400)).fetchone()
            if visit is None:
                raise HTTPException(404, "landing_visit_not_found")
            if body.event == "submitted":
                db.execute("INSERT INTO landing_visit_reports(visit_id,report_id) VALUES(?,?) "
                           "ON CONFLICT DO NOTHING", (str(visit_id), body.report_id))
            elif not db.execute("SELECT 1 FROM landing_visit_reports WHERE visit_id=? AND report_id=?",
                                (str(visit_id), body.report_id)).fetchone():
                # Reopening an older saved report is not a new conversion.
                return
            # The column comes from the event whitelist, never from raw input.
            db.execute(f"UPDATE landing_visits SET {column}=COALESCE({column},?) WHERE id=? AND owner=?",
                       (time.time(), str(visit_id), owner))

    def consent(self, body, owner):
        if not body.granted:
            raise HTTPException(422, "landing_consent_required")
        if body.notice_version != NOTICE_VERSION:
            raise HTTPException(409, "landing_notice_outdated")
        with self.store.connect() as db:
            db.execute("INSERT INTO landing_consents(owner,notice_version,agreed_at) VALUES(?,?,?) "
                       "ON CONFLICT(owner,notice_version) DO NOTHING", (owner, body.notice_version, time.time()))


def landing_router(service):
    router = APIRouter(prefix="/api/landing")

    @router.get("/config")
    async def config(response: Response):
        response.headers["Cache-Control"] = "no-store"
        return {"support_email": service.settings.support_email, "notice_version": NOTICE_VERSION}

    @router.post("/consents")
    async def consent(body: ConsentInput, key: Key):
        service.consent(body, owner_for(key))
        return {"accepted": True, "notice_version": NOTICE_VERSION}

    @router.post("/visits")
    async def visit(body: VisitInput, key: Key):
        service.visit(body, owner_for(key))
        return {"ok": True}

    @router.post("/visits/{visit_id}/events")
    async def event(visit_id: UUID, body: VisitEvent, key: Key):
        service.event(visit_id, body, owner_for(key))
        return {"ok": True}

    return router
