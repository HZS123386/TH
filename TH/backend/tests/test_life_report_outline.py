"""Four-question content, calculated dates and paid access use isolated test data."""
import asyncio
from copy import deepcopy
import json

from fastapi.testclient import TestClient
import pytest

from backend.app.astrology import RoxyAstrology, validate_astrology
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

BODY = {"birthData": {"date": "1992-04-15", "time": "07:15:00", "timezone": "Asia/Bangkok"},
        "startDate": "2026-11-16", "endDate": "2027-02-13"}


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
    chart = {"provider": "roxy", "domain": "astrology", "time_known": True, "raw": GOLDEN, "forecast": forecast}
    bundle = RoxyAstrology.bundle(body, chart, "overview")
    bundle.update(stage="preview", reading="life-preview", preview_layout="four-questions")
    assert not bundle["citation_rules"]["timing_ids"]
    result = LifeWriter.validate(json.dumps(draft(bundle), ensure_ascii=False), bundle)
    assert result["recent"] is None


def test_four_question_api_free_and_paid_share_frozen_calculation(tmp_path, monkeypatch, transport):
    previews = []
    async def write(self, bundle, *args):
        if bundle['stage'] == 'preview':
            previews.append(deepcopy(bundle))
        return self.validate(json.dumps(draft(bundle), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    with TestClient(create_app(settings(tmp_path))) as client:
        preview = client.post('/api/life-reports', json={"profile": PROFILE, "year": 2026}, headers=HEADERS).json()
        assert preview['preview_state'] == 'ready'
        assert all(preview['preview'].get(key) for key in ('environment', 'favorable', 'unfavorable', 'recent', 'response'))
        assert preview['preview']['sample_topic'] == 'career'
        assert 'steps' not in preview['preview']['response']
        assert len(previews[0]['citation_rules']['timing_ids']) == 1
        invalid = draft(previews[0])
        invalid['response']['evidence_ids'] = ['P_venus', 'P_jupiter']
        with pytest.raises(InvalidBaziReport):
            LifeWriter.validate(json.dumps(invalid, ensure_ascii=False), previews[0])
        assert preview['preview']['recent']['window']['timezone'] == 'UTC'
        assert not preview['chapters'] and preview['plan'] is None
        assert set(preview['outlook']) == {'state', 'start', 'end', 'timezone'}
        path = '/api/life-reports/' + preview['id']
        store = client.app.state.store
        with store.connect() as db:
            original = json.loads(db.execute('SELECT chart FROM life_reports WHERE id=?', (preview['id'],)).fetchone()['chart'])['forecast']
        unlock_after_simulated_payment(client, path)
        async def finish():
            await asyncio.gather(*client.app.state.life_reports.tasks.values())
        client.portal.call(finish)
        full = client.get(path, headers=HEADERS).json()
        career = next(chapter for chapter in full['chapters'] if chapter['key'] == 'career')
        assert preview['preview']['recent']['window'] == career['summary']['window']
        assert len(full['chapters']) == 5 and len(full['plan']['phases']) == 3
        assert all(chapter['summary'].get('window') for chapter in full['chapters'])
        assert all(point.get('window') for chapter in full['chapters'] for point in chapter['actions'])
        with store.connect() as db:
            assert json.loads(db.execute('SELECT chart FROM life_reports WHERE id=?', (preview['id'],)).fetchone()['chart'])['forecast'] == original
            db.execute('UPDATE life_reports SET unlocked=0 WHERE id=?', (preview['id'],))
        locked = client.get(path, headers=HEADERS).json()
        assert not locked['chapters'] and locked['plan'] is None
        assert locked['preview'] == preview['preview']
