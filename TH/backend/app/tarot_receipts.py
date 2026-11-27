"""Register the exact cards selected in the Tarot H5 for LINE fulfilment."""

import secrets
from typing import Literal

from fastapi import APIRouter, HTTPException, Request
from psycopg.types.json import Jsonb
from pydantic import Field, StrictBool, model_validator

from .schemas import Input
from .storage import Storage

RECEIPT_PATH = "/api/tarot/receipts"
SPREAD_COUNTS = {"single": 1, "relationship": 3, "decision": 5}
CLAIM_PATTERN = r"^T[1-9][0-9]{4}$"


class TarotCard(Input):
    id: int = Field(strict=True, ge=0, le=21)
    reversed: StrictBool


class TarotReceiptInput(Input):
    request_key: str = Field(pattern=r"^[a-f0-9]{32}$")
    report_id: str = Field(max_length=48, pattern=r"^MIRA-[A-Z0-9-]+$")
    question: str = Field(min_length=1, max_length=180, pattern=r"^[^\x00]+$")
    topic: Literal["work", "connection", "communication", "decision", "single", "general"]
    spread_id: Literal["single", "relationship", "decision"]
    language: Literal["zh", "th"]
    cards: list[TarotCard] = Field(min_length=1, max_length=5)

    @model_validator(mode="after")
    def validate_spread(self):
        if len(self.cards) != SPREAD_COUNTS[self.spread_id] or len({card.id for card in self.cards}) != len(self.cards):
            raise ValueError("Cards must be distinct and match the selected spread.")
        return self


class TarotReceiptLookup(Input):
    code: str = Field(pattern=CLAIM_PATTERN)


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
        cards = Jsonb([card.model_dump() for card in body.cards])
        with store.connect() as db:
            # Retries keep their existing code, and a code collision draws a different number.
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
                        "SELECT claim_code FROM tarot_receipts WHERE request_hash=%s", (request_hash,),
                    ).fetchone()
                if row is not None:
                    return {"claim_code": row["claim_code"]}
        raise HTTPException(503, "busy")

    return router
