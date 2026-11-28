"""Register the exact cards selected in the Tarot H5 for LINE fulfilment."""

import secrets
from typing import Literal

from fastapi import APIRouter, HTTPException, Request
from psycopg.types.json import Jsonb
from pydantic import Field

from .schemas import Input
from .storage import Storage
from .tarot_readings import TarotRequest

RECEIPT_PATH = "/api/tarot/receipts"
CLAIM_PATTERN = r"^(?:T[1-9][0-9]{4}|T-(?:[0-9A-HJKMNP-TV-Z]{12}|[1-9][0-9]{5,17}))$"


class TarotReceiptInput(TarotRequest):
    request_key: str = Field(pattern=r"^[a-f0-9]{32}$")
    report_id: str = Field(max_length=48, pattern=r"^MIRA-[A-Z0-9-]+$")


class TarotReceiptLookup(Input):
    code: str = Field(pattern=CLAIM_PATTERN)


class TarotReceiptAction(TarotReceiptLookup):
    action: Literal["accept", "mark_sent"]


def tarot_receipt_router(store: Storage, *, require_https: bool):
    router = APIRouter(tags=["Tarot"])

    @router.post(RECEIPT_PATH)
    def register_receipt(body: TarotReceiptInput, request: Request):
        origin = request.headers.get("origin")
        if require_https and request.url.scheme != "https":
            raise HTTPException(403, "tarot_https_required")
        if (request.headers.get("sec-fetch-site") == "cross-site"
                or (origin and origin != f"{request.url.scheme}://{request.url.netloc}")):
            raise HTTPException(403, "tarot_origin_rejected")

        request_hash = store.hash(body.request_key)
        saved = body.model_dump(exclude={"request_key"})
        cards = Jsonb(saved["cards"])
        with store.connect() as db:
            # A duplicate request returns its existing code; a code collision gets a new draw.
            for _ in range(10):
                code = f"T{10000 + secrets.randbelow(90000)}"
                row = db.execute(
                    """
                    INSERT INTO tarot_receipts(request_hash, claim_code, report_id, question, topic, spread_id, language, cards)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT DO NOTHING RETURNING claim_code
                    """,
                    (request_hash, code, body.report_id, body.question, body.topic, body.spread_id, body.language, cards),
                ).fetchone()
                if row is None:
                    row = db.execute(
                        """SELECT claim_code, report_id, question, topic, spread_id, language, cards
                           FROM tarot_receipts WHERE request_hash=%s""", (request_hash,),
                    ).fetchone()
                    if row is not None and any(row[field] != value for field, value in saved.items()):
                        raise HTTPException(409, "tarot_receipt_conflict")
                if row is not None:
                    return {"claim_code": row["claim_code"]}
        raise HTTPException(503, "busy")

    return router
