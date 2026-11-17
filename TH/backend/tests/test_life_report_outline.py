"""Four-question content, calculated dates and paid access use isolated test data."""
import asyncio
from copy import deepcopy
import json

from fastapi.testclient import TestClient
import pytest

from backend.app.astrology import FORECAST_VERSION, RoxyAstrology, validate_astrology
from backend.app.bazi_reports import InvalidBaziReport
from backend.app.life_report_content import LifeWriter
from backend.app.life_reports import LifeInput
from backend.app.main import create_app
from backend.app.roxy import RoxyError
from backend.app.storage import Storage
from backend.tests.test_roxy_astrology import (
    GOLDEN, HEADERS, PROFILE, draft, forecast_fixture, settings, unlock_after_simulated_payment,
)
from backend.tests.test_roxy_astrology import transport as roxy_transport

transport = roxy_transport


@pytest.fixture(autouse=True)
def legacy_outline_contract(monkeypatch):
    # Existing saved reports retain this outline after new reports adopt the personal presentation.
    monkeypatch.setattr("backend.app.life_reports.personal_chart", lambda chart: False)

BODY = {"birthData": {"date": "1992-04-15", "time": "07:15:00", "timezone": "Asia/Bangkok"},
        "startDate": "2026-11-16", "endDate": "2027-02-13"}


def mixed_forecast_fixture(body):
    """Synthetic provider shapes, including valid events the report does not use."""
    value = forecast_fixture(body)
    common = {key: value["events"][0][key] for key in ("date", "datetime", "domain", "description", "significance")}
    value["events"].extend([
        {**common, "type": "sign-ingress", "body": "Mercury", "target": "Sagittarius"},
        {**common, "type": "lunar-phase", "body": "Moon", "target": "Gemini", "phase": "full-moon"},
        {**common, "type": "retrograde-station", "body": "Saturn", "station": "direct"},
        {**common, "type": "eclipse", "body": "Moon", "kind": "partial", "obscuration": .7},
        {**value["events"][0], "target": "Chiron", "aspect": "trine"},
        {**value["events"][0], "target": "North Node", "aspect": "square"},
    ])
    value["count"] = len(value["events"])
    return value


def test_mixed_western_forecast_accepts_provider_events_and_keeps_supported_report_evidence(tmp_path, monkeypatch):
    adapter = RoxyAstrology(settings(tmp_path), Storage(str(tmp_path / "isolated.db")))
    async def request(operation, body, *args):
        assert operation == "transits"
        raw = mixed_forecast_fixture(body)
        validate_astrology(operation, raw, body)
        return {"data": raw}
    monkeypatch.setattr(adapter, "request", request)
    profile = LifeInput.model_validate({"profile": PROFILE, "year": 2026}).profile
    forecast = asyncio.run(adapter.forecast(profile, "owner", "network"))
    assert forecast["state"] == "ready" and forecast["version"] == FORECAST_VERSION
    assert len(forecast["events"]) == 4
    assert all(row["type"] == "transit-aspect" and row["target"] not in ("Chiron", "North Node") for row in forecast["events"])
    chart = {"provider": "roxy", "domain": "astrology", "time_known": True, "raw": GOLDEN, "forecast": forecast}
    bundle = RoxyAstrology.bundle(LifeInput.model_validate({"profile": PROFILE, "year": 2026}), chart, "career")
    assert bundle["citation_rules"]["timing_ids"]
    assert all(bundle["evidence"][key]["type"] == "transit" for key in bundle["citation_rules"]["timing_ids"])


@pytest.mark.parametrize("kind,field,value", [
    ("sign-ingress", "target", "Invented Sign"),
    ("lunar-phase", "phase", "third-quarter"),
    ("lunar-phase", "body", "Mars"),
    ("retrograde-station", "station", "unknown"),
    ("eclipse", "kind", "invented"),
    ("eclipse", "body", "Venus"),
    ("eclipse", "obscuration", 1.01),
    ("transit-aspect", "aspect", "invented"),
    ("transit-aspect", "type", "future-promise"),
])
def test_mixed_forecast_rejects_invalid_event_discriminators(kind, field, value):
    raw = mixed_forecast_fixture(BODY)
    row = next(row for row in raw["events"] if row["type"] == kind)
    row[field] = value
    with pytest.raises(RoxyError, match="roxy_invalid_response"):
        validate_astrology("transits", raw, BODY)


def test_forecast_revision_creates_fresh_report_after_saved_unavailable_result(tmp_path, monkeypatch, transport):
    from backend.app import life_reports as reports_module
    async def write(self, bundle, **kwargs):
        return self.validate(json.dumps(draft(bundle), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    with TestClient(create_app(settings(tmp_path))) as client:
        adapter = client.app.state.life_reports.adapters["astrology"]
        real_forecast = adapter.forecast
        async def unavailable(*args):
            return {"version": "previous-forecast", "state": "unavailable", "events": []}
        monkeypatch.setattr(adapter, "forecast", unavailable)
        monkeypatch.setattr(reports_module, "FORECAST_VERSION", "previous-forecast")
        body = {"profile": PROFILE, "year": 2026}
        old = client.post("/api/life-reports", json=body, headers=HEADERS).json()
        assert old["preview_state"] == "ready" and old["outlook"]["state"] == "unavailable"
        monkeypatch.setattr(adapter, "forecast", real_forecast)
        monkeypatch.setattr(reports_module, "FORECAST_VERSION", FORECAST_VERSION)
        new = client.post("/api/life-reports", json=body, headers=HEADERS).json()
        assert new["id"] != old["id"] and new["outlook"]["state"] == "ready"
        assert new["preview"]["recent"]["window"]
        assert client.get("/api/life-reports/" + old["id"], headers=HEADERS).json() == old
        assert client.post("/api/life-reports", json=body, headers=HEADERS).json()["id"] == new["id"]
        assert len(transport[0]) == 1  # The natal calculation remains cached independently.


@pytest.mark.parametrize("corruption", ["birth_date", "birth_time", "timezone", "range", "event_date", "utc", "count", "domain", "score", "orb"])
def test_forecast_rejects_unverified_event_data(corruption):
    value = forecast_fixture(BODY)
    if corruption == "birth_date":
        value["birthData"]["date"] = "1992-04-16"
    elif corruption == "birth_time":
        value["birthData"]["time"] = "08:15:00"
    elif corruption == "timezone":
        value["birthData"]["timezone"] = 8
    elif corruption == "range":
        value["endDate"] = "2027-02-14"
    elif corruption == "event_date":
        value["events"][0]["date"] = "2026-11-15"
    elif corruption == "utc":
        value["events"][0]["datetime"] = value["events"][0]["datetime"].replace("Z", "+07:00")
    elif corruption == "count":
        value["count"] = True
    elif corruption == "domain":
        value["events"][0]["domain"] = "vedic"
    elif corruption == "score":
        value["events"][0]["significance"] = float("nan")
    elif corruption == "orb":
        value["events"][0]["orb"] = -1
    with pytest.raises(RoxyError):
        validate_astrology("transits", value, BODY)


def test_four_question_draft_requires_grounded_answers_and_dates():
    raw = forecast_fixture(BODY)
    chart = {"provider": "roxy", "domain": "astrology", "time_known": True, "raw": GOLDEN,
             "forecast": {"state": "ready", "start": BODY["startDate"], "end": BODY["endDate"], "events": raw["events"]}}
    body = LifeInput.model_validate({"profile": PROFILE, "year": 2026})
    bundle = RoxyAstrology.bundle(body, chart, "overview")
    bundle.update(stage="preview", reading="life-preview", preview_layout="four-questions")
    valid = draft(bundle)
    LifeWriter.validate(json.dumps(valid, ensure_ascii=False), bundle)
    for change in ["missing_answer", "fake_time_id", "missing_time", "invented_date"]:
        changed = deepcopy(valid)
        if change == "missing_answer":
            changed.pop("environment")
        elif change == "fake_time_id":
            changed["recent"]["evidence_ids"][0] = "T_foreign_report"
        elif change == "missing_time":
            changed["recent"] = None
        else:
            changed["recent"]["text"] = "你将在2026年12月25日获得新的工作机会，请提前做好准备。"
        with pytest.raises(InvalidBaziReport):
            LifeWriter.validate(json.dumps(changed, ensure_ascii=False), bundle)


def test_unknown_time_never_requests_a_forecast(tmp_path, monkeypatch):
    adapter = RoxyAstrology(settings(tmp_path), Storage(str(tmp_path / "isolated.db")))
    async def forbidden(*args):
        raise AssertionError("Unknown birth time must not request a timed forecast")
    monkeypatch.setattr(adapter, "request", forbidden)
    profile = LifeInput.model_validate({"profile": {**PROFILE, "birth_time": None}, "year": 2026}).profile
    result = asyncio.run(adapter.forecast(profile, "owner", "network"))
    assert result["state"] == "time_unknown" and result["events"] == []


@pytest.mark.parametrize("state", ["empty", "unavailable"])
def test_missing_forecast_data_keeps_dates_absent(tmp_path, monkeypatch, state):
    adapter = RoxyAstrology(settings(tmp_path), Storage(str(tmp_path / "isolated.db")))
    async def request(operation, body, *args):
        if state == "unavailable":
            raise RoxyError("roxy_unavailable")
        return {"data": {"endDate": body["endDate"], "events": []}}
    monkeypatch.setattr(adapter, "request", request)
    body = LifeInput.model_validate({"profile": PROFILE, "year": 2026})
    forecast = asyncio.run(adapter.forecast(body.profile, "owner", "network"))
    assert forecast.get("failure_code") == ("roxy_unavailable" if state == "unavailable" else None)
    chart = {"provider": "roxy", "domain": "astrology", "time_known": True, "raw": GOLDEN, "forecast": forecast}
    bundle = RoxyAstrology.bundle(body, chart, "overview")
    bundle.update(stage="preview", reading="life-preview", preview_layout="four-questions")
    assert not bundle["citation_rules"]["timing_ids"]
    result = LifeWriter.validate(json.dumps(draft(bundle), ensure_ascii=False), bundle)
    assert result["recent"] is None


@pytest.mark.parametrize("mode", ["known", "unknown", "legacy"])
def test_free_excerpt_reuses_frozen_career_content_without_generating_paid_topics_early(tmp_path, monkeypatch, transport, mode):
    previews, parts = [], []
    async def write(self, bundle, *args):
        if bundle['stage'] == 'preview':
            previews.append(deepcopy(bundle))
        else:
            parts.append(deepcopy(bundle))
        return self.validate(json.dumps(draft(bundle), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    with TestClient(create_app(settings(tmp_path))) as client:
        profile = {**PROFILE, **({"birth_time": None} if mode == "unknown" else {})}
        preview = client.post('/api/life-reports', json={"profile": profile, "year": 2026}, headers=HEADERS).json()
        assert preview['preview_state'] == 'ready'
        assert all(preview['preview'].get(key) for key in ('environment', 'favorable', 'unfavorable', 'response'))
        assert preview['preview']['sample_topic'] == 'career'
        assert 'steps' not in preview['preview']['response']
        assert len(previews) == 1 and parts == []
        assert len(previews[0]['citation_rules']['timing_ids']) == (0 if mode == 'unknown' else 1)
        for key in ('favorable', 'unfavorable', 'response'):
            invalid = draft(previews[0])
            invalid[key]['evidence_ids'] = ['P_venus', 'P_jupiter']
            with pytest.raises(InvalidBaziReport):
                LifeWriter.validate(json.dumps(invalid, ensure_ascii=False), previews[0])
        if mode == 'unknown':
            assert preview['preview'].get('recent') is None
        else:
            assert preview['preview']['recent']['window']['timezone'] == 'UTC'
        assert not preview['chapters'] and preview['plan'] is None
        assert set(preview['outlook']) == {'state', 'start', 'end', 'timezone'}
        path = '/api/life-reports/' + preview['id']
        store = client.app.state.store
        with store.connect() as db:
            original = json.loads(db.execute('SELECT chart FROM life_reports WHERE id=?', (preview['id'],)).fetchone()['chart'])['forecast']
            stored = json.loads(db.execute('SELECT preview FROM life_reports WHERE id=?', (preview['id'],)).fetchone()['preview'])
            assert stored['free_excerpt_origin'] == {'version': 1, 'topic': 'career'}
            if mode == 'legacy':
                stored.pop('free_excerpt_origin')
                db.execute('UPDATE life_reports SET preview=? WHERE id=?', (json.dumps(stored), preview['id']))
        unlock_after_simulated_payment(client, path)
        async def finish():
            await asyncio.gather(*client.app.state.life_reports.tasks.values())
        client.portal.call(finish)
        full = client.get(path, headers=HEADERS).json()
        assert full['full_state'] == 'ready'
        career = next(chapter for chapter in full['chapters'] if chapter['key'] == 'career')
        career_bundle = next(bundle for bundle in parts if bundle.get('reading') == 'career')
        if mode == 'legacy':
            assert 'free_excerpt' not in career_bundle
        else:
            assert set(career_bundle['free_excerpt']) == {'favorable', 'unfavorable', 'recent'}
            for source, point in (('favorable', career['insights'][0]), ('unfavorable', career['watchpoints'][0])):
                assert point['text'] == preview['preview'][source]['text']
                assert point['evidence'] == preview['preview'][source]['evidence']
            if mode != 'unknown':
                assert career['summary'] == preview['preview']['recent']
        assert all('free_excerpt' not in bundle for bundle in parts if bundle.get('reading') != 'career')
        if mode != 'unknown':
            assert preview['preview']['recent']['window'] == career['summary']['window']
        assert len(full['chapters']) == 5 and len(full['plan']['phases']) == 3
        assert all(bool(chapter['summary'].get('window')) == (mode != 'unknown') for chapter in full['chapters'])
        assert all(bool(point.get('window')) == (mode != 'unknown') for chapter in full['chapters'] for point in chapter['actions'])
        with store.connect() as db:
            assert json.loads(db.execute('SELECT chart FROM life_reports WHERE id=?', (preview['id'],)).fetchone()['chart'])['forecast'] == original
            db.execute('UPDATE life_reports SET unlocked=0 WHERE id=?', (preview['id'],))
        locked = client.get(path, headers=HEADERS).json()
        assert not locked['chapters'] and locked['plan'] is None
        assert locked['preview'] == preview['preview']
