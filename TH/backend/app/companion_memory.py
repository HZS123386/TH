"""Adapted from Roxy Labs' MIT src/lib/memory/index.ts, commit 3b313e6972b92aecf94dad2aecbe822e1599fa4a.

Same recall/remember seam and recency fallback; local SQLite replaces Supabase/pgvector.
Conversation archives are distinct from explicit, user-confirmed notes.
"""
import asyncio
import hashlib
import json
import logging
import math

import httpx

from .config import ProviderConfig
from .storage import Storage

logger = logging.getLogger(__name__)


def vector(value):
    if not isinstance(value, list) or not 1 <= len(value) <= 4096:
        raise ValueError("embedding_invalid")
    try:
        if any(isinstance(number, bool) or not isinstance(number, (int, float)) or not math.isfinite(number) for number in value):
            raise ValueError("embedding_invalid")
        norm = math.sqrt(sum(number * number for number in value))
    except OverflowError:
        raise ValueError("embedding_invalid") from None
    if not math.isfinite(norm) or norm == 0:
        raise ValueError("embedding_invalid")
    return [number / norm for number in value]


class CompanionMemory:
    def __init__(self, store: Storage, config: ProviderConfig):
        self.store, self.config = store, config
        self.signature = hashlib.sha256((config.base_url + "/" + config.model).encode()).hexdigest()
        self.slots = asyncio.Semaphore(2)

    async def embed(self, text: str):
        async with self.slots, asyncio.timeout(8):
            async with httpx.AsyncClient(timeout=httpx.Timeout(7, connect=3)) as client:
                response = await client.post(self.config.base_url.rstrip("/") + "/embeddings", headers={"Authorization": "Bearer " + self.config.key}, json={"model": self.config.model, "input": text[:6000]})
                response.raise_for_status()
                return vector(response.json()["data"][0]["embedding"])

    async def recall(self, user_id: str, query: str, count: int = 3):
        rows = self.store.recall_readings(user_id, self.signature)
        mode = "recent"
        selected = rows[:count]
        if rows and self.config.enabled:
            try:
                needle = await self.embed(query)
                ranked = []
                for row in rows:
                    if row["embedding"]:
                        stored = vector(json.loads(row["embedding"]))
                        if len(stored) == len(needle):
                            ranked.append((sum(a * b for a, b in zip(needle, stored)), row))
                if ranked:
                    selected = [row for _, row in sorted(ranked, key=lambda pair: pair[0], reverse=True)[:count]]
                    mode = "semantic"
                else:
                    mode = "recent-unindexed"
            except (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError, TimeoutError):
                # Never log provider bodies, credentials or private conversation text.
                logger.warning("Companion semantic recall unavailable; using recent readings")
                mode = "recent-unavailable"
        return {"mode": mode, "items": [{key: row[key] for key in ("id", "content", "created")} for row in selected]}

    def remember(self, user_id: str, asked: str, shown: str, provider: str, evidence: dict):
        return self.store.save_pair(user_id, asked, shown, provider, evidence)

    async def index(self, user_id: str, message_id: str):
        if not self.config.enabled:
            return
        reading = self.store.reading(user_id, message_id)
        if not reading:
            return
        try:
            embedding = await self.embed(reading["content"])
            self.store.index_reading(user_id, message_id, self.signature, embedding)
        except (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError, TimeoutError):
            logger.warning("Companion reading stored; optional embedding index unavailable")
