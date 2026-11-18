"""Personal reports keep saved access, payment checks and calculations on isolated data."""
import asyncio
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import hashlib
import json

from fastapi.testclient import TestClient
import pytest

from backend.app.astrology import RoxyAstrology
from backend.app.bazi_reports import InvalidBaziReport
from backend.app.life_report_content import PERSONAL_LOVE_FIELDS, LifeWriter
from backend.app.life_reports import LifeInput
from backend.app.main import create_app
from backend.app.storage import Storage
from backend.tests.test_personal_report_content import personal_draft, personal_fixture_bundle
from backend.tests.test_roxy_astrology import HEADERS, PROFILE, forecast_fixture, settings, transport as roxy_transport

transport = roxy_transport


def frozen_forecast(state="ready", *, periods=3):
    events = [{"date": day, "datetime": day + "T12:00:00Z", "domain": "western", "type": "transit-aspect",
               "body": "Jupiter", "target": target, "aspect": "trine", "orb": 0,
               "significance": 82, "description": "An isolated actual-shape transit event."}
              for day, target in zip(("2026-11-23", "2026-12-21", "2027-01-10"), ("Sun", "Mercury", "Venus"))]
    return {"state": state, "start": "2026-11-16", "end": "2027-02-13", "timezone": "UTC", "events": events[:periods] if state == "ready" else []}


def writer_stub(monkeypatch):
    calls = []
    async def write(self, bundle, *args):
        calls.append(deepcopy(bundle))
        return self.validate(json.dumps(personal_draft(bundle), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    return calls


def test_relationship_report_uses_separate_observed_roles_without_requiring_birth_time_or_forecast(postgres_url, monkeypatch, transport):
    calls = []
    context = {
        "status": "single",
        "roles": "前任、朋友",
        "event": "前任两次取消约定又主动另约。朋友建议我给自己留出时间。",
        "source": "direct",
    }

    async def write(self, bundle, *args):
        calls.append(deepcopy(bundle))
        if bundle["stage"] == "personal_preview":
            return self.validate(json.dumps(personal_draft(bundle), ensure_ascii=False), bundle)
        value = {
            "language": "zh", "reading": "relationship-full",
            "people": [
                {"role": "前任", "event_excerpt": "两次取消约定又主动另约", "explanation": "前任的改约让你需要重新考虑要为接触留出多少时间。"},
                {"role": "朋友", "event_excerpt": "建议我给自己留出时间", "explanation": "朋友的建议提醒你把自己的日程也放进这次选择里。"},
            ],
            "portrait": None,
            "impact": "一次次调整相处安排会占用你的空闲时间，也容易让是否继续来往的决定迟迟定不下来。",
            "patterns": [{
                "evidence_id": bundle["citation_rules"]["topic_ids"][0],
                "symbolism": "这项配置传统上与在交流中寻找亲切感有关。",
                "behavior": "可以观察听到解释后，你是否立刻重新腾出时间。",
            }],
            "assessment": "主动另约显示还有协商空间，反复取消也有实际成本，尤其是你为未定的行程留出了大段时间。",
            "continue_when": "选择新对象时，留意表达意愿后愿意一起安排时间的人。",
            "reconsider_when": "如果一听到热络解释就接受长期的不确定，可以把守约和主动协调加进选择标准。",
            "verify": "先确认第二次更改后双方有无落实新的约定。",
            "question": "“我们能选一个都方便并且能落实的时间吗？”",
            "observe": "看看下一次发生变动时，对方会不会提前提出替代安排。",
        }
        rendered = json.dumps(value, ensure_ascii=False)
        for source in ("reported", "guess"):
            uncertain = {**bundle, "relationship_context": {**context, "source": source}}
            with pytest.raises(InvalidBaziReport, match="empty people list"):
                self.validate(rendered, uncertain)
        portrait = deepcopy(value)
        portrait["people"] = []
        portrait["portrait"] = {
            "evidence_id": value["patterns"][0]["evidence_id"],
            "text": "有一种相处风格值得留意。对方会耐心听你把话说完，你也因此愿意聊得更深。可以看看从聊天转到实际安排时，你是否依然觉得自在。",
        }
        assert self.validate(json.dumps(portrait, ensure_ascii=False), uncertain)["portrait"] == portrait["portrait"]
        portrait["portrait"]["evidence_id"] = "fictional-factor"
        with pytest.raises(InvalidBaziReport, match="portrait.*cited patterns"):
            self.validate(json.dumps(portrait, ensure_ascii=False), uncertain)
        invented = deepcopy(value)
        invented["people"][0]["role"] = "对方家人"
        with pytest.raises(InvalidBaziReport, match="exact behavior excerpts"):
            self.validate(json.dumps(invented, ensure_ascii=False), bundle)
        return self.validate(rendered, bundle)

    monkeypatch.setattr(LifeWriter, "write", write)
    with TestClient(create_app(settings(postgres_url))) as client:
        async def forbidden_forecast(*args, **kwargs):
            pytest.fail("The relationship report must accept an absent forecast.")
        monkeypatch.setattr(client.app.state.life_reports.adapters["astrology"], "forecast", forbidden_forecast)
        request = {"profile": {**PROFILE, "birth_time": None}, "year": 2026, "relationship": context}
        response = client.post("/api/life-reports", json=request, headers=HEADERS)
        assert response.status_code == 200, response.text
        free = response.json()
        assert free["personal"]["ascendant_sign"] is None
        assert free["personal"]["relationship_sections"] is None
        assert free["personal"]["availability"]["full_report"]
        assert [bundle["stage"] for bundle in calls] == ["personal_preview"]
        path = "/api/life-reports/" + free["id"]
        assert client.post(path + "/unlock", headers=HEADERS).status_code == 402
        order = client.post(path + "/payment", json={}, headers=HEADERS)
        assert order.status_code == 200, order.text
        assert client.post(path + "/payment/simulate", json={"reference": order.json()["reference"]}, headers=HEADERS).json()["paid"]

        async def finish():
            await asyncio.gather(*client.app.state.life_reports.tasks.values())
        client.portal.call(finish)
        full = client.get(path, headers=HEADERS).json()
        assert full["full_state"] == "ready", full
        assert [bundle["stage"] for bundle in calls] == ["personal_preview", "relationship_full"]
        assert calls[1]["relationship_context"] == context
        assert all(fact["type"] != "transit" for fact in calls[1]["evidence"].values())
        assert [item["key"] for item in full["catalog"]] == ["who", "impact", "pattern", "assessment", "decision", "next_steps"]
        assert "选择" in full["catalog"][4]["title"]
        sections = full["personal"]["relationship_sections"]
        assert [paragraph.split(" · ")[0] for paragraph in sections["who"]] == ["前任", "亲身经历", "朋友", "亲身经历"]
        assert len(sections["next_steps"]) == 3


def test_new_personal_report_shares_two_model_calls_and_never_exposes_paid_data_before_payment(postgres_url, monkeypatch, transport):
    calls = writer_stub(monkeypatch)
    with TestClient(create_app(settings(postgres_url))) as client:
        adapter = client.app.state.life_reports.adapters["astrology"]
        snapshots = []
        async def forecast(*args):
            snapshots.append(frozen_forecast())
            return deepcopy(snapshots[-1])
        monkeypatch.setattr(adapter, "forecast", forecast)
        body = {"profile": PROFILE, "year": 2026, "report_kind": "fortune"}
        response = client.post("/api/life-reports", json=body, headers=HEADERS)
        assert response.status_code == 200, response.text
        free = response.json()
        assert free["format"] == "western-personal" and free["preview_state"] == "ready"
        assert len(free["personal"]["free_lines"]) == 3 and free["personal"]["ascendant_sign"]
        assert len(free["personal"]["traits"]) == 3 and free["personal"]["opportunity_action"]
        assert free["personal"]["relationship"]["text"] and free["personal"]["relationship"]["action"]
        relation = free["personal"]["relationship"]
        assert len(relation["evidence"]) == 2
        assert relation["text"].endswith("（月亮与水星对分相）")
        assert sum(fact["id"].startswith("A") for fact in relation["evidence"]) == 1
        assert free["personal"]["availability"] == {"full_report": True, "reason": "not_started"}
        assert free["personal"]["talent"] is None and free["personal"]["themes"] is None and free["personal"]["nodes"] == []
        assert free["preview"] is None and free["chapters"] == [] and free["plan"] is None
        assert free["outlook"] == {"state": "not_started"}
        assert [item["key"] for item in free["catalog"]] == ["natal", "career", "wealth", "love", "risk", "plan"]
        assert free["progress"] == {"completed": 0, "total": 6}
        assert [call["stage"] for call in calls] == ["personal_preview"]
        assert snapshots == [] and len(transport[0]) == 1
        assert calls[0]["citation_rules"]["months"] == []
        assert not any(fact["type"] == "transit" for fact in calls[0]["evidence"].values())
        assert "2027-01" not in json.dumps(free, ensure_ascii=False)
        path = "/api/life-reports/" + free["id"]
        assert client.get(path, headers={"X-Report-Key": "different-synthetic-owner-key-12345678"}).status_code == 404
        assert client.post("/api/life-reports", json=body, headers=HEADERS).json()["id"] == free["id"]
        assert client.post(path + "/unlock", headers=HEADERS).status_code == 402
        assert snapshots == []
        order = client.post(path + "/payment", json={}, headers=HEADERS)
        assert order.status_code == 200, order.text
        assert len(snapshots) == 1 and [call["stage"] for call in calls] == ["personal_preview"]
        waiting = client.get(path, headers=HEADERS).json()
        assert waiting["access"] == "preview" and waiting["full_state"] == "not_started"
        assert waiting["personal"]["availability"] == {"full_report": True, "reason": "ready"}
        assert client.post(path + "/payment", json={}, headers=HEADERS).json()["reference"] == order.json()["reference"]
        assert len(snapshots) == 1
        paid = client.post(path + "/payment/simulate", json={"reference": order.json()["reference"]}, headers=HEADERS)
        assert paid.status_code == 200 and paid.json()["paid"] is True
        assert client.post(path + "/unlock", headers=HEADERS).status_code == 200
        async def finish():
            await asyncio.gather(*client.app.state.life_reports.tasks.values())
        client.portal.call(finish)
        full = client.get(path, headers=HEADERS).json()
        assert full["full_state"] == "ready", full
        assert [call["stage"] for call in calls] == ["personal_preview", "personal_full"]
        assert len(full["personal"]["talent"]["directions"]) == 3
        assert set(full["personal"]["themes"]) == {"wealth", "love", "risk"}
        assert all(len(item["evidence"]) == 2 for item in full["personal"]["themes"].values())
        assert calls[-1]["previous_points"][:3] == free["personal"]["free_lines"]
        aspect_id = next(fact["id"] for fact in relation["evidence"] if fact["id"].startswith("A"))
        assert calls[-1]["relationship_preview"] == {"text": relation["text"].removesuffix("（月亮与水星对分相）"),
                                                      "action": relation["action"], "natal_aspect_id": aspect_id}
        assert any(fact["id"] == aspect_id for fact in full["personal"]["themes"]["love"]["evidence"])
        unrelated = personal_draft(calls[-1])
        love = unrelated["themes"]["love"]
        assert full["personal"]["themes"]["love"]["text"].split("\n\n") == [love[field] for field in ("text", *PERSONAL_LOVE_FIELDS)]
        assert all(love[field] not in waiting["personal"]["relationship"]["text"] for field in PERSONAL_LOVE_FIELDS)
        assert waiting["personal"]["themes"] is None
        unrelated["themes"]["love"]["evidence_ids"] = [key for key in calls[-1]["citation_rules"]["themes"]["love"] if key != aspect_id][:2]
        with pytest.raises(InvalidBaziReport, match="build on the free relationship aspect"):
            LifeWriter.validate(json.dumps(unrelated, ensure_ascii=False), calls[-1])
        assert [item["month"] for item in full["personal"]["nodes"]] == ["2026-11", "2026-12", "2027-01"]
        assert all(len(item["evidence"]) == 2 for item in full["personal"]["nodes"])
        assert full["progress"] == {"completed": 6, "total": 6} and full["generation_progress"]["percent"] == 100
        assert len(snapshots) == 1 and len(transport[0]) == 1
        with client.app.state.store.connect() as db:
            chapter_snapshot = db.execute("SELECT chapters FROM life_reports WHERE id=%s", (free["id"],)).fetchone()["chapters"]
            previous_chapters = json.loads(chapter_snapshot)
            previous_love = previous_chapters["personal"]["story"]["themes"]["love"]
            for field in PERSONAL_LOVE_FIELDS:
                del previous_love[field]
            db.execute("UPDATE life_reports SET chapters=%s WHERE id=%s", (json.dumps(previous_chapters), free["id"]))
        previous = client.get(path, headers=HEADERS).json()
        assert previous["personal"]["themes"]["love"]["text"] == previous_love["text"]
        with client.app.state.store.connect() as db:
            previous_chapters["personal"]["story"].pop("themes")
            db.execute("UPDATE life_reports SET chapters=%s WHERE id=%s", (json.dumps(previous_chapters), free["id"]))
        previous = client.get(path, headers=HEADERS).json()
        assert previous["full_state"] == "ready" and previous["personal"]["themes"] is None
        assert [item["key"] for item in previous["catalog"]] == ["talent", "node-1", "node-2", "node-3"]
        assert previous["progress"] == {"completed": 4, "total": 4}
        with client.app.state.store.connect() as db:
            db.execute("UPDATE life_reports SET chapters=%s WHERE id=%s", (chapter_snapshot, free["id"]))
        with client.app.state.store.connect() as db:
            original = db.execute("SELECT chart FROM life_reports WHERE id=%s", (free["id"],)).fetchone()["chart"]
            db.execute("UPDATE life_reports SET unlocked=0 WHERE id=%s", (free["id"],))
        locked = client.get(path, headers=HEADERS).json()
        assert locked["personal"]["talent"] is None and locked["personal"]["themes"] is None and locked["personal"]["nodes"] == []
        assert locked["outlook"] == {"state": "ready"}
        with client.app.state.store.connect() as db:
            assert db.execute("SELECT chart FROM life_reports WHERE id=%s", (free["id"],)).fetchone()["chart"] == original
            saved_preview = json.loads(db.execute("SELECT preview FROM life_reports WHERE id=%s", (free["id"],)).fetchone()["preview"])
            saved_preview["story"].pop("traits")
            saved_preview["story"].pop("opportunity_action")
            db.execute("UPDATE life_reports SET preview=%s WHERE id=%s", (json.dumps(saved_preview, ensure_ascii=False), free["id"]))
        saved = client.get(path, headers=HEADERS).json()["personal"]
        assert saved["free_lines"] == free["personal"]["free_lines"]
        assert saved["traits"] == [] and saved["opportunity_action"] == ""
        with client.app.state.store.connect() as db:
            saved_preview["story"].pop("relationship")
            saved_preview["version"] = "western-personal-7"
            db.execute("UPDATE life_reports SET preview=%s WHERE id=%s", (json.dumps(saved_preview, ensure_ascii=False), free["id"]))
        assert client.get(path, headers=HEADERS).json()["personal"]["relationship"] is None
        assert len(calls) == 2  # Opening a saved older report must not spend another generation call.


@pytest.mark.parametrize("state,known,periods,reason,status", [
    ("time_unknown", False, 0, "time_unknown", 422),
    ("ready", True, 2, "insufficient_periods", 409),
])
def test_free_personal_report_can_be_read_but_payment_is_blocked_without_three_actual_months(postgres_url, monkeypatch, transport, state, known, periods, reason, status):
    calls = writer_stub(monkeypatch)
    with TestClient(create_app(settings(postgres_url))) as client:
        async def forecast(*args):
            return frozen_forecast(state, periods=periods)
        monkeypatch.setattr(client.app.state.life_reports.adapters["astrology"], "forecast", forecast)
        body = {"profile": {**PROFILE, "birth_time": PROFILE["birth_time"] if known else None}, "year": 2026}
        report = client.post("/api/life-reports", json=body, headers=HEADERS).json()
        assert report["preview_state"] == "ready", report
        assert len(report["personal"]["free_lines"]) == 3
        assert bool(report["personal"]["ascendant_sign"]) == known
        assert report["personal"]["availability"] == {"full_report": known, "reason": "not_started" if known else "time_unknown"}
        path = "/api/life-reports/" + report["id"]
        assert client.post(path + "/payment", headers=HEADERS, json={}).status_code == status
        assert client.post(path + "/unlock", headers=HEADERS).status_code == 402
        assert client.get(path, headers=HEADERS).json()["personal"]["availability"] == {"full_report": False, "reason": reason}
        assert report["personal"]["nodes"] == [] and len(calls) == 1
        with client.app.state.store.connect() as db:
            assert db.execute("SELECT COUNT(*) AS total FROM life_card_payments").fetchone()["total"] == 0


def test_personal_month_selection_uses_real_distinct_months_and_keeps_free_input_private():
    bundle = personal_fixture_bundle(full=True)
    rules = bundle["citation_rules"]["months"]
    assert len({item["month"] for item in rules}) == 3
    for item in rules:
        fact = bundle["evidence"][item["transit_id"]]
        assert fact["event_date"][:7] == item["month"]
        assert item["supporting_natal_ids"] == ["P_" + fact["target"]]
    free = personal_fixture_bundle()
    assert not free["citation_rules"]["months"]
    assert set(free["forecast"]) == {"state"}


@pytest.mark.parametrize("state,periods", [("unavailable", 0), ("ready", 0)])
def test_failed_or_empty_paid_forecast_keeps_free_report_and_retries_at_checkout(postgres_url, monkeypatch, transport, state, periods):
    calls = writer_stub(monkeypatch)
    with TestClient(create_app(settings(postgres_url))) as client:
        mode, attempts = {"state": state, "periods": periods}, []
        async def forecast(profile, owner, network, *, refresh=False):
            attempts.append(refresh)
            return frozen_forecast(mode["state"], periods=mode["periods"])
        monkeypatch.setattr(client.app.state.life_reports.adapters["astrology"], "forecast", forecast)
        body = {"profile": PROFILE, "year": 2026}
        free = client.post("/api/life-reports", json=body, headers=HEADERS).json()
        assert free["preview_state"] == "ready" and len(free["personal"]["free_lines"]) == 3
        assert len(calls) == 1 and attempts == []
        path = "/api/life-reports/" + free["id"]
        assert client.post(path + "/payment", json={}, headers=HEADERS).status_code == 409
        assert client.post(path + "/unlock", headers=HEADERS).status_code == 402
        failed = client.get(path, headers=HEADERS).json()
        assert failed["preview_state"] == "ready" and failed["personal"]["free_lines"] == free["personal"]["free_lines"]
        assert failed["full_state"] == "not_started" and failed["access"] == "preview"
        assert attempts == [False] and len(calls) == 1
        with client.app.state.store.connect() as db:
            assert db.execute("SELECT COUNT(*) AS total FROM life_card_payments").fetchone()["total"] == 0
        mode.update(state="ready", periods=3)
        assert client.post(path + "/payment", json={}, headers=HEADERS).status_code == 200
        recovered = client.post("/api/life-reports", json=body, headers=HEADERS).json()
        assert recovered["id"] == failed["id"] and recovered["input"] == failed["input"]
        assert recovered["preview_state"] == "ready" and len(recovered["personal"]["free_lines"]) == 3
        assert attempts == [False, True] and len(calls) == 1
        with client.app.state.store.connect() as db:
            assert db.execute("SELECT COUNT(*) AS total FROM life_card_payments").fetchone()["total"] == 1


def test_personal_forecast_refresh_clears_only_its_own_memory_cache_and_failure(postgres_url, monkeypatch):
    adapter = RoxyAstrology(settings(postgres_url), Storage(postgres_url))
    profile = LifeInput.model_validate({"profile": PROFILE, "year": 2026}).profile
    start = datetime.now(timezone.utc).date()
    body = {"birthData": {"date": PROFILE["birth_date"], "time": PROFILE["birth_time"] + ":00", "timezone": PROFILE["timezone"]},
            "startDate": start.isoformat(), "endDate": (start + timedelta(days=89)).isoformat(), "minSignificance": 0}
    key = hashlib.sha256(json.dumps(["transits", body, "en", "owner"], sort_keys=True).encode()).hexdigest()
    adapter.cache[key] = (999999999999, {})
    adapter.failures[key] = (999999999999, "roxy_unavailable")
    adapter.cache["other-owner"] = (999999999999, {})
    adapter.failures["other-owner"] = (999999999999, "roxy_unavailable")
    async def request(operation, received, language, owner, network):
        assert operation == "transits" and received == body
        assert key not in adapter.cache and key not in adapter.failures
        assert "other-owner" in adapter.cache and "other-owner" in adapter.failures
        return {"data": forecast_fixture(body)}
    monkeypatch.setattr(adapter, "request", request)
    assert asyncio.run(adapter.forecast(profile, "owner", "network", refresh=True))["state"] == "ready"
