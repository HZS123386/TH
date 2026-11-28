"""JY's first-party funnel and data-use confirmation on the existing backend."""
import hashlib
import time
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, Request, Response
from pydantic import Field, StrictBool, model_validator

from .schemas import Input

NOTICE_VERSION = "h5-data-use-3"
VISIT_RETENTION_SECONDS = 30 * 86400
Key = Annotated[str, Header(alias="X-Report-Key", min_length=32, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")]


def owner_for(key):
    return "life:" + hashlib.sha256(key.encode()).hexdigest()


def device_from_headers(headers):
    platform = headers.get("sec-ch-ua-platform", "").strip(' "').lower()
    agent = headers.get("user-agent", "").lower()
    # A tablet can report ?0, so use its platform or User-Agent before checking for desktop.
    if (headers.get("sec-ch-ua-mobile") == "?1" or platform in ("android", "ios", "ipados")
            or any(marker in agent for marker in ("android", "iphone", "ipad", "ipod", "mobile", "kindle", "silk/"))):
        return "mobile"
    if (platform in ("windows", "macos", "linux", "chrome os")
            or any(marker in agent for marker in ("windows nt", "macintosh", "x11", "cros", "linux"))):
        return "desktop"
    return None


class VisitActivity(Input):
    page: Literal["welcome", "birth_form", "consent", "history", "privacy", "support", "unobserved",
                  "generating_preview", "generating_full", "report_loading", "preview_report", "full_report", "payment"]
    action: Literal["view", "enter_form", "edit_form", "invalid_form", "consent_accept", "consent_cancel",
                    "generate", "generation_failed", "retry_generation", "cancel_generation", "report_ready",
                    "report_failed", "open_payment", "close_payment", "create_order", "order_created",
                    "order_failed", "invalid_phone", "open_cashier", "cashier_failed", "check_payment",
                    "payment_result", "close_history", "leave_page", "request_failed", "select_birth_date",
                    "select_birth_time", "select_birthplace", "form_progress_empty", "form_progress_date",
                    "form_progress_time", "form_progress_place", "form_progress_complete",
                    "open_line_contact", "line_qr_shown", "click_welcome_start", "click_generate_report", "click_line",
                    "runtime_boot_html", "runtime_boot_timeout", "runtime_boot_entry", "runtime_boot_engine",
                    "runtime_boot_app", "runtime_script_load", "runtime_js_type", "runtime_js_reference",
                    "runtime_js_syntax", "runtime_js_range", "runtime_js_error", "runtime_rejection",
                    "runtime_flutter_widgets", "runtime_flutter_rendering", "runtime_flutter_framework"]
    state: Literal["visible", "hidden", "pagehide"]
    sequence: int = Field(strict=True, ge=1, le=9007199254740991)


class VisitInput(Input):
    id: UUID
    source: str = Field(default="", max_length=64, pattern=r"^[A-Za-z0-9_.~-]*$")
    campaign: str = Field(default="", max_length=64, pattern=r"^[A-Za-z0-9_.~-]*$")
    region: str | None = Field(default=None, pattern=r"^[A-Z]{2}$")
    activity: VisitActivity | None = None
    events: list["ActivityEvent"] = Field(default_factory=list, max_length=20)
    dropped_events: int = Field(default=0, strict=True, ge=0, le=2147483647)


class ActivityEvent(VisitActivity):
    page_view_id: UUID
    kind: Literal["action", "state", "dwell"] = "action"
    occurred_at: float = Field(ge=0, le=4102444800, allow_inf_nan=False)
    visible_ms: int = Field(strict=True, ge=0, le=30 * 86400 * 1000)
    failure_code: Literal["network", "badResult"] | None = None
    failure_path: Literal["/api/life-reports", "/api/life-reports/{report_id}",
                          "/api/life-reports/submissions/{submission_id}",
                          "/api/life-reports/{report_id}/unlock", "/api/life-reports/{report_id}/payment",
                          "/api/life-reports/{report_id}/payment/check", "/api/life-reports/{report_id}/payment/simulate",
                          "/api/thai-locations", "/api/landing/config", "/api/landing/consents",
                          "/api/landing/visits/{visit_id}/events"] | None = None
    failure_method: Literal["GET", "POST", "DELETE"] | None = None

    @model_validator(mode="after")
    def failure_fields(self):
        fields = (self.failure_code, self.failure_path, self.failure_method)
        if (self.action == "request_failed" and self.kind == "action" and not all(fields)) or (any(fields) and (self.action != "request_failed" or not all(fields))):
            raise ValueError("Invalid client failure fields")
        return self


class VisitEvent(Input):
    report_id: str = Field(min_length=8, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")
    event: Literal["submitted", "seen", "line_contact"]


class ConsentInput(Input):
    notice_version: str = Field(min_length=1, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")
    granted: StrictBool


def record_visit(db, body, owner, *, device_type=None):
    now = time.time()
    cutoff = now - VISIT_RETENTION_SECONDS
    db.execute("DELETE FROM landing_visits WHERE visited_at < %s", (cutoff,))
    db.execute("DELETE FROM landing_visitors WHERE last_visited_at < %s", (cutoff,))
    db.execute("""
        INSERT INTO landing_visits(id,owner,source,campaign,visited_at,region_code,device_type)
        VALUES(%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT(id) DO UPDATE SET device_type=EXCLUDED.device_type
        WHERE landing_visits.owner=EXCLUDED.owner AND landing_visits.device_type IS NULL
          AND EXCLUDED.device_type IS NOT NULL
    """, (str(body.id), owner, body.source, body.campaign, now, body.region, device_type))
    row = db.execute("SELECT owner,visited_at,source,campaign,region_code FROM landing_visits WHERE id=%s FOR UPDATE",
                     (str(body.id),)).fetchone()
    if row is None or row["owner"] != owner:
        raise HTTPException(404, "landing_visit_not_found")
    visited_at = row["visited_at"]
    if body.dropped_events:
        db.execute("UPDATE landing_visits SET dropped_events=GREATEST(dropped_events,%s) WHERE id=%s",
                   (body.dropped_events, str(body.id)))
    # Later visits refresh the retention window without redefining first-touch tags.
    db.execute("""
        INSERT INTO landing_visitors(owner,region_code,first_visit_date,last_visited_at,first_source,first_campaign)
        VALUES(%s,%s,(to_timestamp(%s) AT TIME ZONE 'Asia/Shanghai')::date,%s,%s,%s)
        ON CONFLICT(owner) DO UPDATE SET last_visited_at=EXCLUDED.last_visited_at
        WHERE landing_visitors.last_visited_at < EXCLUDED.last_visited_at
    """, (owner, row["region_code"], visited_at, visited_at, row["source"], row["campaign"]))
    activities = [body.activity] if body.activity else []
    for activity in body.events:
        # A retry is the same event, so its time and duration must not be counted twice.
        inserted = db.execute("""
            INSERT INTO landing_visit_activity(visit_id,sequence,page_view_id,page,action,state,kind,
                occurred_at,received_at,visible_ms)
            VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING
        """, (str(body.id), activity.sequence, str(activity.page_view_id), activity.page, activity.action,
              activity.state, activity.kind, activity.occurred_at, now, activity.visible_ms))
        if inserted.rowcount:
            activities.append(activity)
            if activity.failure_code:
                db.execute("""INSERT INTO h5_request_failures(created,method,path,http_status,code,duration_ms,report_id,owner,visit_id)
                    VALUES(%s,%s,%s,0,%s,0,'',%s,%s)""",
                    (now, activity.failure_method, activity.failure_path, "client_" + activity.failure_code, owner, str(body.id)))
    if any(item.failure_code for item in body.events):
        db.execute("DELETE FROM h5_request_failures WHERE created<%s", (cutoff,))
        db.execute("DELETE FROM h5_request_failures WHERE id IN (SELECT id FROM h5_request_failures ORDER BY created DESC OFFSET 20000)")
    if activities:
        activity = max(activities, key=lambda item: item.sequence)
        # Delayed requests must not replace a newer page or a return from the cashier.
        db.execute("""
            UPDATE landing_visits SET last_page=%s,last_action=%s,last_activity_at=%s,
                last_state=%s,last_activity_sequence=%s
            WHERE id=%s AND owner=%s AND (last_activity_sequence IS NULL OR last_activity_sequence<%s)
        """, (activity.page, activity.action, now, activity.state, activity.sequence,
              str(body.id), owner, activity.sequence))


def record_submission(db, visit_id, report_id, owner):
    db.execute("INSERT INTO landing_visit_reports(visit_id,report_id) VALUES(%s,%s) "
               "ON CONFLICT DO NOTHING", (visit_id, report_id))
    db.execute("UPDATE landing_visits SET submitted_at=COALESCE(submitted_at,%s) WHERE id=%s AND owner=%s",
               (time.time(), visit_id, owner))


class LandingFeatures:
    def __init__(self, store, settings, reports):
        self.store, self.settings, self.reports = store, settings, reports

    def visit(self, body, owner, *, device_type=None):
        with self.store.connect() as db:
            record_visit(db, body, owner, device_type=device_type)

    def event(self, visit_id, body, owner):
        report = self.reports.row(body.report_id, owner)
        if body.event in ("seen", "line_contact") and not report["preview"]:
            raise HTTPException(409, "life_preview_required")
        visit_id = str(visit_id)
        with self.store.connect() as db:
            visit = db.execute("SELECT 1 FROM landing_visits WHERE id=%s AND owner=%s AND visited_at>=%s FOR UPDATE",
                               (visit_id, owner, time.time() - VISIT_RETENTION_SECONDS)).fetchone()
            if visit is None:
                raise HTTPException(404, "landing_visit_not_found")
            if body.event == "submitted":
                record_submission(db, visit_id, body.report_id, owner)
                return True
            if body.event == "line_contact":
                db.execute("UPDATE life_reports SET line_contact_at=%s "
                           "WHERE id=%s AND owner=%s AND line_contact_at IS NULL",
                           (time.time(), body.report_id, owner))
                return True
            if not db.execute("SELECT 1 FROM landing_visit_reports WHERE visit_id=%s AND report_id=%s",
                              (visit_id, body.report_id)).fetchone():
                # Reopening an older saved report is not a new conversion.
                return False
            db.execute("UPDATE landing_visits SET seen_at=COALESCE(seen_at,%s) WHERE id=%s AND owner=%s",
                       (time.time(), visit_id, owner))
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
    async def visit(body: VisitInput, key: Key, request: Request):
        service.visit(body, owner_for(key), device_type=device_from_headers(request.headers))
        return {"ok": True, "accepted_sequences": [event.sequence for event in body.events]}

    @router.post("/visits/{visit_id}/events")
    async def event(visit_id: UUID, body: VisitEvent, key: Key):
        return {"ok": True, "recorded": service.event(visit_id, body, owner_for(key))}

    return router
