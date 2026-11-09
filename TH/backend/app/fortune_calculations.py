"""Short-lived, account-scoped calculation reuse for preview -> report requests."""
import asyncio
from collections import OrderedDict
from copy import deepcopy
from datetime import datetime
import time
from zoneinfo import ZoneInfo

from . import thai
from .opastro_adapter import digest


class FortuneCalculations:
    def __init__(self, slots: asyncio.Semaphore):
        self.slots = slots
        self.entries = OrderedDict()
        self.pending = {}

    async def get(self, profile, period, owner):
        now = datetime.now(ZoneInfo("Asia/Bangkok"))
        key = (owner, digest(profile), period, now.strftime("%Y-%m-%dT%H:%M"))
        for stale in [entry for entry, (expires, _) in self.entries.items() if expires <= time.monotonic()]:
            del self.entries[stale]
        cached = self.entries.get(key)
        if cached:
            self.entries.move_to_end(key)
            return deepcopy(cached[1])
        task = self.pending.get(key)
        if task is None:
            if len(self.pending) >= 64:
                raise RuntimeError("busy")

            async def calculate():
                async with self.slots:
                    value = await asyncio.to_thread(thai.fortune, profile, period, now)
                self.entries[key] = (time.monotonic() + 30, value)
                while len(self.entries) > 64:
                    self.entries.popitem(last=False)
                return value

            task = asyncio.create_task(calculate())
            self.pending[key] = task

            def completed(task):
                self.pending.pop(key, None)
                # Consume errors even if all HTTP callers have disconnected.
                if not task.cancelled():
                    task.exception()

            task.add_done_callback(completed)
        # Cancelling one tab must not cancel another caller's shared calculation.
        return deepcopy(await asyncio.shield(task))
