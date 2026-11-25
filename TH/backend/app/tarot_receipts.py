"""Register a Tarot LINE request in the shared FATE backend."""

import secrets
from typing import Literal

from fastapi import APIRouter, HTTPException, Response
from psycopg.types.json import Jsonb
from pydantic import Field, StrictBool, model_validator

from .schemas import Input

RECEIPT_PATH = "/api/tarot/receipts"
SPREAD_COUNTS = {"single": 1, "relationship": 3, "decision": 5}
CLAIM_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
CLAIM_PATTERN = r"^T-(?:[0-9A-HJKMNP-TV-Z]{12}|[1-9][0-9]{5,17})$"


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


class TarotReceiptAction(TarotReceiptLookup):
    action: Literal["accept", "mark_sent"]


def tarot_receipt_router(store):
    router = APIRouter(tags=["Tarot"])

    @router.post(RECEIPT_PATH)
    def register_receipt(body: TarotReceiptInput, response: Response):
        request_hash = store.hash(body.request_key)
        cards = Jsonb([card.model_dump() for card in body.cards])
        with store.connect() as db:
            # A duplicate request returns its existing code; a code collision gets a new draw.
            for _ in range(5):
                code = "T-" + "".join(secrets.choice(CLAIM_ALPHABET) for _ in range(12))
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
                    response.headers["Cache-Control"] = "no-store"
                    return {"claim_code": row["claim_code"]}
        raise HTTPException(503, "busy")

    return router
