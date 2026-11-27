"""Collect anonymous page views and actions from the Tarot H5."""

from typing import Literal, get_args
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, Request, Response
from pydantic import Field

from .schemas import Input
from .storage import Storage

ACTIVITY_PATH = "/api/tarot/activity"
VISITOR_HEADER = "X-Tarot-Visitor"
VISITOR_PATTERN = r"^[a-f0-9]{32}$"

TarotPage = Literal["home", "draw", "reflection", "report_loading", "report", "archive", "line_receipt", "chat"]
TarotAction = Literal[
    "reading_start", "draw_first_started", "draw_first_resumed", "card_selected",
    "draw_first_question_confirmed", "draw_resumed", "question_confirmed", "spread_matched",
    "clarification_shown", "question_clarified", "spread_changed", "spread_confirmed",
    "free_report_generated", "line_message_copied", "line_open_clicked", "report_export",
    "app_handoff", "companion_message", "plan_checked", "suggestion_refresh",
    "consultation_example_selected", "consultation_cta",
]
TAROT_PAGES = get_args(TarotPage)
TAROT_ACTIONS = get_args(TarotAction)


class PageObservation(Input):
    id: UUID
    event: TarotPage
    visible_ms: int = Field(strict=True, ge=0, le=2_147_483_647)


class ActionObservation(Input):
    id: UUID
    event: TarotAction


class TarotActivity(Input):
    observations: list[PageObservation | ActionObservation] = Field(min_length=1, max_length=40)


def tarot_activity_router(store: Storage, *, require_https: bool):
    router = APIRouter(tags=["Tarot"])

    @router.post(ACTIVITY_PATH, status_code=204, response_class=Response)
    def record_activity(
        body: TarotActivity,
        request: Request,
        visitor: str = Header(alias=VISITOR_HEADER, pattern=VISITOR_PATTERN),
    ):
        origin = request.headers.get("origin")
        if require_https and request.url.scheme != "https":
            raise HTTPException(403, "tarot_https_required")
        if (request.headers.get("sec-fetch-site") not in (None, "same-origin")
                or (origin and origin != f"{request.url.scheme}://{request.url.netloc}")):
            raise HTTPException(403, "tarot_origin_rejected")

        visitor_hash = store.hash(visitor)
        rows = [
            (entry.id, visitor_hash, entry.event, entry.visible_ms if isinstance(entry, PageObservation) else None)
            for entry in sorted(body.observations, key=lambda entry: entry.id)
        ]
        with store.connect() as db, db.cursor() as cursor:
            # Keep one row per observation even when the browser retries or sends older checkpoints late.
            cursor.executemany("""
                INSERT INTO tarot_activity (id, visitor_hash, event, visible_ms)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET visible_ms=EXCLUDED.visible_ms
                WHERE tarot_activity.visitor_hash=EXCLUDED.visitor_hash
                  AND tarot_activity.event=EXCLUDED.event
                  AND EXCLUDED.visible_ms>tarot_activity.visible_ms
            """, rows)

    return router
