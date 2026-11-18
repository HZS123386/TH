"""Preview latency checks use isolated storage and synthetic external responses."""
import asyncio
from copy import deepcopy
import json

import httpx
import pytest

from backend.app.astrology import VERSION, RoxyAstrology
from backend.app.config import ProviderConfig
from backend.app.life_reports import LifeInput, LifeReports
from backend.app.life_report_content import LifeWriter
from backend.app.main import create_app
from backend.app.roxy import RoxyError
from backend.app.storage import Storage
from backend.tests.test_roxy_astrology import GOLDEN, HEADERS, PROFILE, forecast_fixture, settings
from backend.tests.test_personal_report_content import personal_draft
from backend.tests.test_personal_reports import frozen_forecast, transport as personal_transport

transport = personal_transport


def test_free_context_keeps_facts_and_summaries_without_changing_full_source():
    body = LifeInput.model_validate({"profile": PROFILE, "year": 2026})
    chart = {"time_known": True, "raw": deepcopy(GOLDEN)}
    chart["raw"]["planets"][0]["interpretation"] = {"summary": "A concise natal tendency.", "detailed": "Extra explanation. " * 60}
    chart["raw"]["planets"][1]["interpretation"] = {"detailed": "Keep this source when no summary exists."}
    original = deepcopy(chart)
    free = RoxyAstrology.personal_bundle(body, chart)
    full = RoxyAstrology.personal_bundle(body, chart, full=True)
    assert free["personal_signs"] == full["personal_signs"]
    assert free["evidence"].keys() <= full["evidence"].keys()
    for identifier, short in free["evidence"].items():
        fact = full["evidence"][identifier]
        assert {k: v for k, v in short.items() if k != "interpretation"} == {k: v for k, v in fact.items() if k != "interpretation"}
        if fact.get("interpretation", {}).get("summary"):
            assert short["interpretation"] == {"summary": fact["interpretation"]["summary"]}
    assert "detailed" in full["evidence"]["P_sun"]["interpretation"]
    assert free["evidence"]["P_moon"]["interpretation"] == full["evidence"]["P_moon"]["interpretation"]
    assert chart == original
    assert set(full["citation_rules"]["themes"]) == {"wealth", "love", "risk"}
    assert all(set(ids) <= full["evidence"].keys() and len(ids) >= 2 for ids in full["citation_rules"]["themes"].values())


def test_preview_writer_sends_compact_facts_but_keeps_display_evidence(tmp_path):
    config = settings(tmp_path)
    writer = LifeWriter(Storage(config.database_path), config, asyncio.Semaphore(1))
    body = LifeInput.model_validate({"profile": PROFILE, "year": 2026, "user_question": "怎样处理感情分歧？"})
    chart = {"time_known": True, "raw": deepcopy(GOLDEN)}
    chart["raw"]["planets"][0]["interpretation"] = {"summary": "A real source note."}
    bundle = RoxyAstrology.personal_bundle(body, chart)
    bundle["user_question"] = body.user_question
    original = deepcopy(bundle)

    model_input = writer.model_input(bundle)
    assert bundle == original
    assert model_input["user_question"] == body.user_question
    assert model_input["personal_signs"] == bundle["personal_signs"]
    assert model_input["citation_rules"]["relationship_ids"] == bundle["citation_rules"]["relationship_ids"]
    assert model_input["evidence"].keys() == bundle["evidence"].keys()
    assert model_input["evidence"]["P_sun"]["source_note"] == "A real source note."
    assert "detail" not in model_input["evidence"]["P_sun"] and bundle["evidence"]["P_sun"]["detail"]
    assert len(json.dumps(model_input, ensure_ascii=False)) < len(json.dumps(bundle, ensure_ascii=False))


def test_preview_wait_returns_on_completion_and_cancelling_reader_keeps_job(tmp_path, monkeypatch):
    async def run():
        app = create_app(settings(tmp_path))
        service = app.state.life_reports
        started, release = asyncio.Event(), asyncio.Event()

        async def calculate(*args):
            return {"provider": "roxy", "domain": "astrology", "status": "ready", "source": "https://roxyapi.com/docs/guides/astrology",
                    "version": VERSION, "location": {"latitude": 13.75, "longitude": 100.5},
                    "time_known": True, "raw": deepcopy(GOLDEN)}

        async def write(writer, bundle, *args):
            started.set()
            await release.wait()
            return writer.validate(json.dumps(personal_draft(bundle), ensure_ascii=False), bundle)

        monkeypatch.setattr(service.adapters["astrology"], "calculate", calculate)
        monkeypatch.setattr(LifeWriter, "write", write)
        try:
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
                created = (await client.post("/api/life-reports?wait=false", headers=HEADERS,
                                             json={"profile": PROFILE, "year": 2026})).json()
                await asyncio.wait_for(started.wait(), 1)
                path = "/api/life-reports/" + created["id"]
                waiting = path + "?wait_preview=true"
                assert (await client.get(path, headers=HEADERS)).json()["preview_state"] == "generating"
                foreign = await client.get(waiting, headers={"X-Report-Key": "different-synthetic-owner-key-12345678"})
                assert foreign.status_code == 404
                reader = asyncio.create_task(client.get(waiting, headers=HEADERS))
                await asyncio.sleep(.02)
                reader.cancel()
                await asyncio.gather(reader, return_exceptions=True)
                assert not service.preview_tasks[created["id"]].done()
                reader = asyncio.create_task(client.get(waiting, headers=HEADERS))
                await asyncio.sleep(.02)
                assert not reader.done()
                release.set()
                response = await asyncio.wait_for(reader, 1)
                assert response.status_code == 200 and response.json()["preview_state"] == "ready"
                assert len(response.json()["personal"]["traits"]) == 3
        finally:
            release.set()
            await service.close()

    asyncio.run(run())


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
        config.fortune_provider = "openai"
        config.fortune_fallback_provider = "qwen"
        config.providers["openai"] = ProviderConfig(
            "writer-test-key", "https://model.example/v1", "gpt-6.1-sol", reasoning_effort="low",
        )
        config.life_preview_openai_model = "gpt-6.1-terra"
        config.life_preview_openai_reasoning_effort = "none"
        config.life_preview_openai_languages = frozenset({"zh", "th"})
        service = LifeReports(Storage(config.database_path), config, asyncio.Semaphore(4), asyncio.Semaphore(2))
        writer = service.preview_writer_for("zh")
        assert (writer.config.model, writer.config.reasoning_effort) == ("gpt-6.1-terra", "none")
        assert service.preview_writer_for("lo").config == service.parts_writer.config == config.providers["openai"]
        assert service.preview_writer_for("lo").availability is service.parts_writer.availability
        assert writer.availability is not service.parts_writer.availability
        assert writer.fallback_writer.config == config.providers["qwen"]
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
        monkeypatch.setattr(writer, "write", preview_write)
        paid = [asyncio.create_task(service.parts_writer.generate(
            service.adapters["astrology"].bundle(body, chart, topic), "owner", "network"))
            for topic in ("natal", "career", "wealth", "love")]
        try:
            await asyncio.wait_for(three_running.wait(), .5)
            # Let the fourth paid task reach its gate before starting the free request.
            await asyncio.sleep(0)
            bundle = service.adapters["astrology"].bundle(body, chart, "overview")
            bundle.update(stage="preview", reading="life-preview")
            result = await asyncio.wait_for(writer.generate(bundle, "free-owner", "network"), .5)
            assert result["state"] == "ready" and result["story"] == {"synthetic": "preview"}
            assert active == 3
        finally:
            release.set()
            await asyncio.gather(*paid)

    asyncio.run(run())
