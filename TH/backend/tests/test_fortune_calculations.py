import asyncio
from copy import deepcopy
from datetime import datetime, timedelta
from threading import Event

from backend.app import fortune_calculations as module


def test_identical_preview_and_report_reuse_calculation_but_never_cross_scope(monkeypatch):
    calls = []

    def calculate(profile, period, now):
        calls.append((deepcopy(profile), period, now))
        return {"birth": profile["birth_date"], "nested": {"value": 1}}

    monkeypatch.setattr(module.thai, "fortune", calculate)

    async def run():
        cache = module.FortuneCalculations(asyncio.Semaphore(2))
        profile = {"birth_date": "1999-02-20", "language": "zh"}
        first = await cache.get(profile, "today", "a")
        first["nested"]["value"] = 999
        assert (await cache.get(profile, "today", "a"))["nested"]["value"] == 1
        assert len(calls) == 1
        await cache.get(profile, "today", "b")
        await cache.get({**profile, "birth_date": "2001-05-06"}, "today", "a")
        await cache.get(profile, "week", "a")
        await cache.get({**profile, "language": "th"}, "today", "a")
        assert len(calls) == 5

    asyncio.run(run())


def test_simultaneous_calls_share_work_and_one_disconnect_does_not_cancel_others(monkeypatch):
    started, release = Event(), Event()
    calls = []

    def calculate(*args):
        calls.append(True)
        started.set()
        assert release.wait(3)
        return {"ready": True}

    monkeypatch.setattr(module.thai, "fortune", calculate)

    async def run():
        cache = module.FortuneCalculations(asyncio.Semaphore(2))
        first = asyncio.create_task(cache.get({}, "today", "a"))
        assert await asyncio.to_thread(started.wait, 2)
        second = asyncio.create_task(cache.get({}, "today", "a"))
        await asyncio.sleep(0)
        first.cancel()
        await asyncio.gather(first, return_exceptions=True)
        release.set()
        assert await second == {"ready": True}
        assert len(calls) == 1 and not cache.pending

    asyncio.run(run())


def test_cache_respects_minute_midnight_expiry_and_capacity(monkeypatch):
    moment = [datetime.fromisoformat("2026-11-06T23:59:50+07:00")]
    ticks = [100]
    calls = []

    class Clock(datetime):
        @classmethod
        def now(cls, zone):
            return moment[0]

    def calculate(profile, period, now):
        calls.append(True)
        return {"date": now.date().isoformat()}

    monkeypatch.setattr(module, "datetime", Clock)
    monkeypatch.setattr(module.time, "monotonic", lambda: ticks[0])
    monkeypatch.setattr(module.thai, "fortune", calculate)

    async def run():
        cache = module.FortuneCalculations(asyncio.Semaphore(2))
        assert (await cache.get({}, "today", "a"))["date"] == "2026-11-06"
        moment[0] += timedelta(seconds=15)
        assert (await cache.get({}, "today", "a"))["date"] == "2026-11-07"
        ticks[0] += 31
        await cache.get({}, "today", "a")
        assert len(calls) == 3
        for index in range(70):
            await cache.get({}, "today", str(index))
        assert len(cache.entries) == 64

    asyncio.run(run())


def test_failed_calculation_is_not_cached_and_can_retry(monkeypatch):
    calls = []

    def calculate(*args):
        calls.append(True)
        if len(calls) == 1:
            raise RuntimeError("thai_calculation_failed")
        return {"ready": True}

    monkeypatch.setattr(module.thai, "fortune", calculate)

    async def run():
        cache = module.FortuneCalculations(asyncio.Semaphore(2))
        result = await asyncio.gather(cache.get({}, "today", "a"), return_exceptions=True)
        assert isinstance(result[0], RuntimeError)
        assert await cache.get({}, "today", "a") == {"ready": True}

    asyncio.run(run())
