"""Preview latency checks use isolated storage and synthetic external responses."""
import asyncio
from copy import deepcopy
import json

import pytest

from backend.app.astrology import RoxyAstrology
from backend.app.life_reports import LifeInput, LifeReports
from backend.app.life_report_content import LifeWriter
from backend.app.roxy import RoxyError
from backend.app.storage import Storage
from backend.tests.test_roxy_astrology import GOLDEN, PROFILE, forecast_fixture, settings
from backend.tests.test_personal_report_content import personal_draft
from backend.tests.test_personal_reports import frozen_forecast, transport as personal_transport

transport = personal_transport


def test_personal_free_report_does_not_wait_for_paid_calculations(tmp_path, monkeypatch, transport):
    async def run():
        config = settings(tmp_path)
        service = LifeReports(Storage(config.database_path), config, asyncio.Semaphore(4), asyncio.Semaphore(2))
        body = LifeInput.model_validate({"profile": PROFILE, "year": 2026})
        started, release = asyncio.Event(), asyncio.Event()
        calls, order_task = [], None

        async def forecast(*args):
            started.set()
            await release.wait()
            return frozen_forecast()

        async def write(writer, bundle, *args):
            calls.append(bundle["stage"])
            return writer.validate(json.dumps(personal_draft(bundle), ensure_ascii=False), bundle)

        monkeypatch.setattr(service.adapters["astrology"], "forecast", forecast)
        monkeypatch.setattr(LifeWriter, "write", write)
        try:
            free = await asyncio.wait_for(service.create(body, "owner", "network"), 1)
            assert free["preview_state"] == "ready" and not started.is_set()
            assert free["full_state"] == "not_started" and calls == ["personal_preview"]
            await service.start_full_generation(free["id"], "owner", "network")
            assert not service.tasks and not started.is_set()  # No unpaid background work, even via an internal caller.
            order_task = asyncio.create_task(service.create_card_order(free["id"], "owner", "network"))
            await asyncio.wait_for(started.wait(), 1)
            waiting = service.get(free["id"], "owner")
            assert waiting["preview_state"] == "ready" and waiting["personal"]["free_lines"] == free["personal"]["free_lines"]
            assert waiting["access"] == "preview" and calls == ["personal_preview"]
            with service.store.connect() as db:
                assert db.execute("SELECT COUNT(*) FROM life_card_payments").fetchone()[0] == 0
            release.set()
            await asyncio.wait_for(order_task, 1)
            assert not service.tasks and calls == ["personal_preview"]
        finally:
            release.set()
            if order_task:
                await asyncio.gather(order_task, return_exceptions=True)
            await service.close()

    asyncio.run(run())


def test_report_calculations_overlap_and_forecast_is_kept(tmp_path, monkeypatch):
    adapter = RoxyAstrology(settings(tmp_path), Storage(str(tmp_path / "calculations.db")))
    profile = LifeInput.model_validate({"profile": PROFILE, "year": 2026}).profile

    async def run():
        started, release = set(), asyncio.Event()

        async def request(operation, body, language, owner, network):
            started.add(operation)
            if len(started) == 2:
                release.set()
            # Serial execution cannot reach the second calculation before this deadline.
            await asyncio.wait_for(release.wait(), .5)
            return {"data": deepcopy(GOLDEN) if operation == "natal" else forecast_fixture(body)}

        monkeypatch.setattr(adapter, "request", request)
        chart = await adapter.calculate(profile, "owner", "network", include_forecast=True)
        assert started == {"natal", "transits"}
        assert chart["raw"] == GOLDEN and chart["forecast"]["state"] == "ready"

    asyncio.run(run())


def test_failed_natal_calculation_releases_the_forecast_waiter(tmp_path, monkeypatch):
    adapter = RoxyAstrology(settings(tmp_path), Storage(str(tmp_path / "cancel.db")))
    profile = LifeInput.model_validate({"profile": PROFILE, "year": 2026}).profile

    async def run():
        forecast_started, forecast_cancelled = asyncio.Event(), asyncio.Event()

        async def request(operation, body, language, owner, network):
            if operation == "natal":
                await forecast_started.wait()
                raise RoxyError("roxy_invalid_response")
            forecast_started.set()
            try:
                await asyncio.Event().wait()
            finally:
                forecast_cancelled.set()

        monkeypatch.setattr(adapter, "request", request)
        with pytest.raises(RoxyError, match="roxy_invalid_response"):
            await adapter.calculate(profile, "owner", "network", include_forecast=True)
        assert forecast_cancelled.is_set()

    asyncio.run(run())


def test_paid_generation_leaves_a_model_slot_for_free_preview(tmp_path, monkeypatch):
    async def run():
        config = settings(tmp_path)
        service = LifeReports(Storage(config.database_path), config, asyncio.Semaphore(4), asyncio.Semaphore(2))
        body = LifeInput.model_validate({"profile": PROFILE, "year": 2026})
        chart = {"time_known": True, "raw": deepcopy(GOLDEN)}
        release, three_running = asyncio.Event(), asyncio.Event()
        active = 0

        async def paid_write(bundle, **kwargs):
            nonlocal active
            active += 1
            if active == 3:
                three_running.set()
            await release.wait()
            active -= 1
            return {"synthetic": "paid"}

        async def preview_write(bundle, **kwargs):
            return {"synthetic": "preview"}

        monkeypatch.setattr(service.parts_writer, "write", paid_write)
        monkeypatch.setattr(service.writer, "write", preview_write)
        paid = [asyncio.create_task(service.parts_writer.generate(
            service.adapters["astrology"].bundle(body, chart, topic), "owner", "network"))
            for topic in ("natal", "career", "wealth", "love")]
        try:
            await asyncio.wait_for(three_running.wait(), .5)
            # Let the fourth paid task reach its gate before starting the free request.
            await asyncio.sleep(0)
            bundle = service.adapters["astrology"].bundle(body, chart, "overview")
            bundle.update(stage="preview", reading="life-preview")
            result = await asyncio.wait_for(service.writer.generate(bundle, "free-owner", "network"), .5)
            assert result["state"] == "ready" and result["story"] == {"synthetic": "preview"}
            assert active == 3
        finally:
            release.set()
            await asyncio.gather(*paid)

    asyncio.run(run())
