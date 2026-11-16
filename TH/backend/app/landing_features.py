"""JY's first-party funnel and data-use confirmation on the existing backend."""
import hashlib
import time
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, Response
from pydantic import Field, StrictBool

from .schemas import Input

NOTICE_VERSION = "h5-data-use-3"
VISIT_RETENTION_SECONDS = 30 * 86400
Key = Annotated[str, Header(alias="X-Report-Key", min_length=32, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")]


def owner_for(key):
    return "life:" + hashlib.sha256(key.encode()).hexdigest()


class VisitInput(Input):
    id: UUID
    source: str = Field(default="", max_length=64, pattern=r"^[A-Za-z0-9_.~-]*$")
    campaign: str = Field(default="", max_length=64, pattern=r"^[A-Za-z0-9_.~-]*$")
    region: str | None = Field(default=None, pattern=r"^[A-Z]{2}$")


class VisitEvent(Input):
    report_id: str = Field(min_length=8, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")
    event: Literal["submitted", "seen"]


class ConsentInput(Input):
    notice_version: str = Field(min_length=1, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")
    granted: StrictBool


def record_visit(db, body, owner):
    now = time.time()
    cutoff = now - VISIT_RETENTION_SECONDS
    db.execute("DELETE FROM landing_visits WHERE visited_at < %s", (cutoff,))
    db.execute("DELETE FROM landing_visitors WHERE last_visited_at < %s", (cutoff,))
    db.execute("""
        INSERT INTO landing_visits(id,owner,source,campaign,visited_at,region_code)
        VALUES(%s,%s,%s,%s,%s,%s) ON CONFLICT(id) DO NOTHING
    """, (str(body.id), owner, body.source, body.campaign, now, body.region))
    row = db.execute("SELECT owner,visited_at,source,campaign,region_code FROM landing_visits WHERE id=%s",
                     (str(body.id),)).fetchone()
    if row is None or row["owner"] != owner:
        raise HTTPException(404, "landing_visit_not_found")
    visited_at = row["visited_at"]
    # Later visits refresh the retention window without redefining first-touch tags.
    db.execute("""
        INSERT INTO landing_visitors(owner,region_code,first_visit_date,last_visited_at,first_source,first_campaign)
        VALUES(%s,%s,(to_timestamp(%s) AT TIME ZONE 'Asia/Shanghai')::date,%s,%s,%s)
        ON CONFLICT(owner) DO UPDATE SET last_visited_at=EXCLUDED.last_visited_at
        WHERE landing_visitors.last_visited_at < EXCLUDED.last_visited_at
    """, (owner, row["region_code"], visited_at, visited_at, row["source"], row["campaign"]))


class LandingFeatures:
    def __init__(self, store, settings, reports):
        self.store, self.settings, self.reports = store, settings, reports

    def visit(self, body, owner):
        with self.store.connect() as db:
            record_visit(db, body, owner)

    def event(self, visit_id, body, owner):
        report = self.reports.row(body.report_id, owner)
        if body.event == "seen" and not report["preview"]:
            raise HTTPException(409, "life_preview_required")
        column = "submitted_at" if body.event == "submitted" else "seen_at"
        with self.store.connect() as db:
            visit = db.execute("SELECT 1 FROM landing_visits WHERE id=%s AND owner=%s AND visited_at>=%s FOR UPDATE",
                               (str(visit_id), owner, time.time() - VISIT_RETENTION_SECONDS)).fetchone()
            if visit is None:
                raise HTTPException(404, "landing_visit_not_found")
            if body.event == "submitted":
                db.execute("INSERT INTO landing_visit_reports(visit_id,report_id) VALUES(%s,%s) "
                           "ON CONFLICT DO NOTHING", (str(visit_id), body.report_id))
            elif not db.execute("SELECT 1 FROM landing_visit_reports WHERE visit_id=%s AND report_id=%s",
                                (str(visit_id), body.report_id)).fetchone():
                # Reopening an older saved report is not a new conversion.
                return False
            # The column comes from the event whitelist, never from raw input.
            db.execute(f"UPDATE landing_visits SET {column}=COALESCE({column},%s) WHERE id=%s AND owner=%s",
                       (time.time(), str(visit_id), owner))
        return True

    def consent(self, body, owner):
        if not body.granted:
            raise HTTPException(422, "landing_consent_required")
        if body.notice_version != NOTICE_VERSION:
            raise HTTPException(409, "landing_notice_outdated")
        with self.store.connect() as db:
            db.execute("INSERT INTO landing_consents(owner,notice_version,agreed_at) VALUES(%s,%s,%s) "
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
        return {"ok": True, "recorded": service.event(visit_id, body, owner_for(key))}

    return router
