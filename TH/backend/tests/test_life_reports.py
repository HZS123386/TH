"""Synthetic model output exercises the real chart, transport and persistence."""
import asyncio
from copy import deepcopy
import json
import time

from fastapi.testclient import TestClient
import httpx
import pytest

from backend.app.config import ProviderConfig, Settings
from backend.app.life_report_content import LifeWriter, preview_writing_progress, validate_life_story, validate_text, writing_progress
from backend.app.life_reports import LifeInput
from backend.app.main import create_app
from backend.app.bazi_reports import BaziReports, InvalidBaziReport

PROFILE = {"display_name": "", "birth_date": "1995-08-17", "birth_time": "09:30", "birthplace": "Bangkok, TH", "timezone": "Asia/Bangkok", "language": "zh", "country_code": "TH", "location_id": "geonames:1609350", "latitude": None, "longitude": None}
HEADERS = {"X-Report-Key": "test-owner-key-with-more-than-thirty-two-characters", "Accept-Language": "zh"}
WORDS = ["先确认清楚任务", "给安排留些余地", "把需要表达清楚", "遇到变化先核对", "选择能做到的事", "完成以后再复盘"]
TRAIT = "遇到一件要求还不清楚的事情时，你可能更愿意先问清楚完成标准，再选择怎样投入。比如接到临时安排，可以先确认对方最在意的结果，再决定从哪一部分开始。这样能让准备更踏实，也减少反复修改的时间。如果事情需要先试一版，可以约定一个较小的范围，做完后再根据反馈调整，不必等到所有条件都确定。"
TEXT = "先把这件事情的要求和已有安排写清楚，再和相关的人确认优先顺序。遇到临时变化时，可以先说清自己能够完成的范围，避免在条件不明确时把所有事情都答应下来。"
TOPICS = {"overview": "生活", "money": "收入", "work": "工作", "love": "相处", "family": "家庭", "annual": "安排"}


def story_for(bundle):
    def ids(index, key=None):
        if bundle["reading"] == "annual":
            return [["M1_sun", "P_sun"], ["M5_jupiter", "P_sun"], ["M9_saturn", "P_sun"]][index % 3]
        if key:
            return [{"strength": "H1", "decisions": "H9", "relationships": "H7"}[key], "P_sun"]
        return [bundle["topic_evidence"][index % len(bundle["topic_evidence"])], "P_sun"]
    base = {"language": bundle["language"], "reading": bundle["reading"]}
    if bundle["stage"] == "plan":
        actions = list(bundle["source_actions"])
        return {**base, "phases": [{"key": key, "title": WORDS[index], "text": WORDS[index] + TEXT, "action_ids": actions[index * 2:index * 2 + 2]} for index, key in enumerate(("observe", "adjust", "review"))]}
    summary = {"text": "先把真正重要的事情说清楚，再选择适合自己的投入方式。", "evidence_ids": ids(0)}
    if bundle["stage"] == "preview":
        if bundle.get("user_question"):
            summary = {"text": "先和家人约定可以独处的时间，再一起商量哪些家务需要共同分担。", "evidence_ids": ["H4", "P_sun"]}
        return {**base, "summary": summary, "traits": [{"key": key, "title": WORDS[index], "text": WORDS[index] + TRAIT, "evidence_ids": ids(index, key)} for index, key in enumerate(("strength", "decisions", "relationships"))]}
    topic = TOPICS[bundle["reading"]]
    def row(index):
        return {"title": topic + WORDS[index], "text": topic + WORDS[index] + TEXT, "evidence_ids": ids(index)}
    insights = [{**row(i), "example": WORDS[i] + "：可以先询问对方，这件事情最需要完成的是哪一部分。", "response": WORDS[i] + "：先从一个能完成的小范围开始，再决定是否扩大安排。"} for i in range(2)]
    watchpoints = [{**row(i + 2), "signals": [WORDS[i] + "：还没问清楚要求，就已经答应承担全部事情。", WORDS[i] + "：原先约定的重要事情，不断被临时的任务打断。"], "response": WORDS[i] + "：先把手头安排说清楚，再和对方一起决定先做什么。", "example": WORDS[i] + "：如果临时收到请求，可以先问清楚是否需要调整原先的顺序。"} for i in range(2)]
    actions = [{**row(i + 4), "steps": [WORDS[i] + "：写下需要完成的事情，挑出最值得先完成的一件。", WORDS[i] + "：确认怎样算完成，并把具体要求和相关的人核对。", WORDS[i] + "：先做一个可以检查的小部分，根据实际结果调整安排。", WORDS[i] + "：完成后对照约定查看，记下下次仍然值得保留的做法。"], "example": WORDS[i] + "：可以问对方，你最希望我先完成哪一部分，然后再确定后面的安排。", "pitfall": WORDS[i] + "：不要只顾反复准备，却一直不选择一个具体的小行动。", "check": WORDS[i] + "：看看任务是否更容易推进，以及来回确认的次数是否减少。"} for i in range(2)]
    return {**base, "summary": summary, "insights": insights, "watchpoints": watchpoints, "actions": actions}


@pytest.fixture
def client(tmp_path, monkeypatch):
    calls = []
    mode = {"fail": None}
    async def write(self, bundle, **kwargs):
        calls.append(deepcopy(bundle))
        if bundle["stage"] == "chapter" and bundle["reading"] == mode["fail"]:
            raise InvalidBaziReport("synthetic unavailable")
        return self.validate(json.dumps(story_for(bundle), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    settings = Settings(database_path=str(tmp_path / "life.db"), providers={"qwen": ProviderConfig("test-key", "https://model.example/v1", "test")}, bazi_reports_per_minute=100, bazi_reports_per_day=100)
    app = create_app(settings)
    app.state.life_report_gate = asyncio.Event()
    parts_writer = app.state.life_reports.parts_writer
    async def delayed_full_write(bundle, **kwargs):
        await app.state.life_report_gate.wait()
        return await type(parts_writer).write(parts_writer, bundle, **kwargs)
    parts_writer.write = delayed_full_write
    with TestClient(app) as http:
        yield http, app, calls, mode


def preview(http):
    response = http.post("/api/life-reports", json={"profile": PROFILE, "year": 2027}, headers=HEADERS)
    assert response.status_code == 200, response.text
    result = response.json()
    assert result["preview_state"] == "ready", result
    return result


def finish(http, app):
    async def wait():
        app.state.life_report_gate.set()
        await asyncio.gather(*list(app.state.life_reports.tasks.values()))
    http.portal.call(wait)


def test_preview_is_personal_and_does_not_return_paid_chapters(client):
    http, _, calls, _ = client
    result = preview(http)
    assert result["title"] == "远程解析"
    assert len(result["preview"]["traits"]) == 3 and len(result["catalog"]) == 5
    assert result["chapters"] == [] and result["plan"] is None
    assert result["access"] == "preview" and result["price"]["mode"] == "direct"
    assert "birth_date" not in json.dumps(calls[0])
    assert all(len(row["evidence"]) == 2 for row in result["preview"]["traits"])
    assert preview(http)["id"] == result["id"] and len(calls) == 1


def test_payso_demo_only_unlocks_the_order_verified_by_inquiry(client, monkeypatch):
    http, app, _, _ = client
    payments = app.state.life_reports.card_payments
    monkeypatch.setattr(payments, "enabled", True)
    monkeypatch.setattr(payments, "merchant", "12345678")
    report = preview(http)
    assert report["price"] == {"amount": 5000, "currency": "THB", "display": "฿50", "mode": "payso_test"}
    path = f"/api/life-reports/{report['id']}"
    checkout = http.post(f"{path}/payment", headers=HEADERS).json()
    reference = checkout["fields"]["refno"]
    assert checkout["fields"]["total"] == "50.00"
    assert http.post(f"{path}/payment", headers=HEADERS).json() == checkout
    assert http.post(f"{path}/payment/check", headers={"X-Report-Key": "z" * 48}).status_code == 404
    assert http.post(f"{path}/unlock", headers=HEADERS).status_code == 402

    result = []

    async def inquiry(ref):
        assert ref == reference
        return result

    monkeypatch.setattr(payments, "inquiry", inquiry)
    postback = "/api/life-reports/payment/payso/postback"
    notice = {"refno": reference, "total": "50", "completed": "true"}
    assert http.post(postback, data=notice).status_code == 409
    result.append({"ReferenceNo": reference, "MerchantID": "12345678", "Total": "49.00",
                   "CurrencyCode": "00", "Status": "CP", "OrderNo": "123456", "CardType": "V"})
    assert http.post(f"{path}/payment/check", headers=HEADERS).json() == {"paid": False}
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"

    result[0]["Total"] = "50.00"
    assert http.post(f"{path}/payment/check", headers=HEADERS).json() == {"paid": True}
    assert http.post(postback, data=notice).status_code == 200
    finish(http, app)
    paid = http.get(path, headers=HEADERS).json()
    assert paid["access"] == "full" and paid["full_state"] == "ready" and paid["chapters"]


def test_career_stage_is_persisted_and_unlock_uses_the_same_30_day_window(client):
    http, app, calls, _ = client
    body = {"profile": {**PROFILE, "birth_time": None}, "year": 2025,
            "career": {"stage": "offer", "start": "2025-12-20"}}
    response = http.post("/api/life-reports", json=body, headers=HEADERS)
    assert response.status_code == 200, response.text
    free = response.json()
    assert free["input"]["career"] == body["career"]
    assert free["price"]["display"] == "฿99" and free["price"]["currency"] == "THB"
    assert free["reference_period"] == {"start": "2025-12-20", "end": "2026-01-18"}
    assert free["time_accuracy"]["mode"] == "estimated"
    assert [item["title"] for item in free["preview"]["traits"]] == ["如果留下", "如果换走", "眼下先做什么"]
    assert free["title"] == "新公司在等答复，我接还是留？"
    assert "接 offer" in free["preview"]["summary"]["text"]
    assert free["access"] == "preview" and not free["chapters"]

    assert http.post("/api/life-reports", json=body, headers=HEADERS).json()["id"] == free["id"]
    other_stage = {**body, "career": {**body["career"], "stage": "considering"}}
    another = http.post("/api/life-reports", json=other_stage, headers=HEADERS).json()
    assert another["title"] == "今天该辞职，还是先找下家？"
    assert another["id"] != free["id"] and another["preview"]["summary"]["text"] != free["preview"]["summary"]["text"]

    focused_body = {**body, "career": {**body["career"], "focus": "move"}}
    focused_response = http.post("/api/life-reports", json=focused_body, headers=HEADERS)
    assert focused_response.status_code == 200, focused_response.text
    focused = focused_response.json()
    assert focused["input"]["career"] == focused_body["career"] and focused["id"] != free["id"]
    assert focused["preview"]["summary"]["text"].startswith("先核对岗位职责、试用期考核和书面薪资。")
    assert http.get(f"/api/life-reports/{focused['id']}", headers=HEADERS).json()["preview"] == focused["preview"]

    url = f"/api/life-reports/{free['id']}"
    assert http.post(url + "/unlock", json={}, headers=HEADERS).status_code == 200
    finish(http, app)
    paid = http.get(url, headers=HEADERS).json()
    assert paid["full_state"] == "ready" and paid["progress"] == {"completed": 1, "total": 1}
    assert paid["reference_period"] == free["reference_period"] and paid["preview"] == free["preview"]
    assert [item["title"].split(" · ")[0] for item in paid["chapters"][0]["insights"]] == [
        "留任的观察时段", "换岗的观察时段", "重新比较",
    ]
    assert not calls


def test_career_question_is_answered_in_the_same_complete_report(client):
    http, app, _, _ = client
    question = {"stage": "offer", "start": "2025-12-20"}
    response = http.post("/api/life-reports", json={"profile": PROFILE, "year": 2025, "career_question": question}, headers=HEADERS)
    assert response.status_code == 200, response.text
    free = response.json()
    assert free["input"]["career_question"] == {**question, "focus": None}
    assert free["title"] == "远程解析"
    assert free["price"] == {"amount": 5000, "currency": "THB", "display": "฿50", "mode": "direct"}
    assert free["preview"]["career_answer"]["text"].startswith("如果新岗位能解决你最想离开的原因")
    assert free["preview"]["career_answer"]["evidence"]
    assert len(free["preview"]["traits"]) == 3 and len(free["catalog"]) == 5
    assert not free["chapters"]

    url = f"/api/life-reports/{free['id']}"
    assert http.post(url + "/unlock", json={}, headers=HEADERS).status_code == 200
    finish(http, app)
    full = http.get(url, headers=HEADERS).json()
    assert full["id"] == free["id"] and full["preview"] == free["preview"]
    assert full["full_state"] == "ready" and full["plan"]
    assert [row["key"] for row in full["chapters"]] == ["work", "money", "love", "family", "annual"]


def test_custom_question_is_saved_and_drives_the_free_summary(client):
    http, app, calls, _ = client
    question = "怎么和家人商量独处时间？"
    body = {"profile": PROFILE, "year": 2025, "user_question": f"  {question}  "}
    response = http.post("/api/life-reports", json=body, headers=HEADERS)
    assert response.status_code == 200, response.text
    report = response.json()
    assert report["input"]["user_question"] == question
    assert calls[0]["user_question"] == question
    assert {"H2", "H4", "H10"} <= set(calls[0]["citation_rules"]["summary_house_ids"])
    prompt = app.state.life_reports.writer.prompt(calls[0])
    assert "answer the concern in user_question" in prompt and question not in prompt
    assert "独处的时间" in report["preview"]["summary"]["text"]
    assert len(report["preview"]["traits"]) == 3 and len(report["catalog"]) == 5
    saved = http.get(f"/api/life-reports/{report['id']}", headers=HEADERS).json()
    assert saved["input"] == report["input"] and saved["preview"] == report["preview"]
    for invalid in (" ", "问" * 121, "问题\x00内容"):
        assert http.post("/api/life-reports", json={**body, "user_question": invalid}, headers=HEADERS).status_code == 422
    conflict = {**body, "career_question": {"stage": "offer", "start": "2025-12-20"}}
    assert http.post("/api/life-reports", json=conflict, headers=HEADERS).status_code == 422


def test_direct_unlock_finishes_all_chapters_and_a_grounded_plan(client):
    http, app, calls, _ = client
    result = preview(http)
    unlocked = http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    assert unlocked.status_code == 200 and unlocked.json()["access"] == "full"
    finish(http, app)
    full = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert full["full_state"] == "ready", full
    assert full["progress"] == {"completed": 5, "total": 5}
    assert [row["key"] for row in full["chapters"]] == ["work", "money", "love", "family", "annual"]
    assert len(full["plan"]["phases"]) == 3
    assert full["chapters"][-1]["insights"][0]["period"] == {"year": 2027, "month": 1}
    assert len({action["chapter"] for phase in full["plan"]["phases"] for action in phase["actions"]}) >= 3
    assert len(calls) == 7
    again = http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    assert again.json()["full_state"] == "ready" and len(calls) == 7


def test_paid_work_starts_only_after_unlock_and_cached_views_do_not_restart_it(client):
    http, app, calls, _ = client
    result = preview(http)
    assert result["access"] == "preview" and result["full_state"] == "not_started"
    assert result["generation_progress"]["percent"] == 0
    assert not app.state.life_reports.tasks
    finish(http, app)
    waiting = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert waiting["full_state"] == "not_started" and len(calls) == 1
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    full = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert full["access"] == "full" and full["full_state"] == "ready"
    assert full["generation_progress"]["percent"] == 100
    assert len(full["chapters"]) == 5 and full["plan"]
    assert len(calls) == 7
    assert preview(http)["id"] == result["id"]
    assert len(calls) == 7
    for bundle in calls[1:]:
        assert isinstance(bundle["preview"]["summary"], str)
        assert all("evidence_ids" not in trait for trait in bundle["preview"]["traits"])


def test_chapter_citation_feedback_identifies_all_invalid_fields(client):
    http, app, calls, _ = client
    result = preview(http)
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    bundle = next(row for row in calls if row["stage"] == "chapter")
    story = story_for(bundle)
    story["insights"][0]["evidence_ids"] = ["H7", "P_sun"]
    story["actions"][1]["evidence_ids"] = ["H1", "H1"]
    story["actions"][0]["text"] = "先确认目标，再选择一个能够开始的行动。"
    with pytest.raises(InvalidBaziReport) as error:
        validate_life_story(json.dumps(story, ensure_ascii=False), bundle)
    assert "insights[0].evidence_ids" in error.value.feedback
    assert "actions[1].evidence_ids" in error.value.feedback
    assert "unknown IDs=['H7']" in error.value.feedback
    assert "chapter text lengths" in error.value.feedback
    assert "actions[0].text" in error.value.feedback


def test_chapter_correction_identifies_forbidden_terms_in_all_public_fields(client):
    http, app, calls, _ = client
    result = preview(http)
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    bundle = next(row for row in calls if row["stage"] == "chapter")
    story = story_for(bundle)
    story["actions"][0]["steps"][1] += "从太阳的状态来决定先后。"
    story["watchpoints"][1]["response"] += "到了三月就会出现新的变化。"
    with pytest.raises(InvalidBaziReport) as error:
        validate_life_story(json.dumps(story, ensure_ascii=False), bundle)
    assert "actions[0].steps[1]" in error.value.feedback and "太阳" in error.value.feedback
    assert "watchpoints[1].response" in error.value.feedback and "三月" in error.value.feedback


def test_schema_correction_identifies_all_invalid_fields_without_input_values(client):
    http, app, calls, _ = client
    result = preview(http)
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    bundle = next(row for row in calls if row["stage"] == "chapter")
    story = story_for(bundle)
    story["actions"][0]["steps"][0] = "私人短句甲"
    story["actions"][1]["steps"][2] = "私人短句乙"
    story["stage"] = "chapter"
    with pytest.raises(InvalidBaziReport) as error:
        validate_life_story(json.dumps(story, ensure_ascii=False), bundle)
    assert "actions.0.steps.0" in error.value.feedback
    assert "actions.1.steps.2" in error.value.feedback
    assert "私人短句" not in error.value.feedback
    assert '"field": "stage"' in error.value.feedback and "REMOVE this unexpected key entirely" in error.value.feedback


def test_long_paid_narrative_has_room_to_explain_and_remains_bounded(client):
    http, app, calls, _ = client
    result = preview(http)
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    bundle = next(row for row in calls if row["stage"] == "chapter")
    story = story_for(bundle)
    story["insights"][0]["text"] = TEXT + TRAIT
    assert len(story["insights"][0]["text"]) > 180
    assert validate_life_story(json.dumps(story, ensure_ascii=False), bundle)
    original = story["insights"][1]["text"]
    story["insights"][1]["text"] = story["insights"][0]["text"]
    with pytest.raises(InvalidBaziReport, match="different personal point"):
        validate_life_story(json.dumps(story, ensure_ascii=False), bundle)
    story["insights"][1]["text"] = original
    story["insights"][0]["text"] = TEXT + TRAIT + TEXT + TRAIT
    with pytest.raises(InvalidBaziReport, match="shorten public field"):
        validate_life_story(json.dumps(story, ensure_ascii=False), bundle)


def test_saved_advice_resolves_its_source_even_when_that_source_is_not_a_paid_section(client):
    http, app, calls, _ = client
    report = preview(http)
    http.post(f"/api/life-reports/{report['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    with app.state.store.connect() as db:
        row = db.execute("SELECT chapters,plan FROM life_reports WHERE id=?", (report["id"],)).fetchone()
        records, plan = json.loads(row["chapters"]), json.loads(row["plan"])
        records["overview"] = deepcopy(records["work"])
        plan["phases"][0]["action_ids"][0] = "overview:0"
        db.execute("UPDATE life_reports SET chapters=?,plan=? WHERE id=?", (json.dumps(records), json.dumps(plan), report["id"]))
    result = http.post(f"/api/life-reports/{report['id']}/unlock", json={}, headers=HEADERS).json()
    assert result["full_state"] == "ready" and len(result["chapters"]) == 5
    assert result["progress"] == {"completed": 5, "total": 5}
    assert result["plan"]["phases"][0]["actions"][0]["chapter"] == "overview"
    assert len(calls) == 7


def test_report_history_and_feedback_are_bound_to_this_device_key(client):
    http, _, calls, _ = client
    result = preview(http)
    other = {**HEADERS, "X-Report-Key": "a-different-owner-key-with-thirty-two-characters"}
    assert http.get(f"/api/life-reports/{result['id']}", headers=other).status_code == 404
    assert http.get("/api/life-reports", headers=other).json()["items"] == []
    feedback = http.post(f"/api/life-reports/{result['id']}/feedback", json={"rating": "partly"}, headers=HEADERS)
    assert feedback.status_code == 200
    assert http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()["feedback"] == "partly"
    assert len(calls) == 1
    assert http.get("/api/life-reports", headers=HEADERS).json()["items"][0]["id"] == result["id"]


@pytest.mark.parametrize("birth_time", ["09:30", None])
def test_incomplete_birth_data_does_not_call_the_writer(client, birth_time):
    http, _, calls, _ = client
    response = http.post("/api/life-reports", json={"profile": {**PROFILE, "birth_time": birth_time, "birthplace": "missing-location", "location_id": None}, "year": 2027}, headers=HEADERS)
    assert response.status_code == 422 and calls == []


def test_unknown_birth_time_generates_an_explicit_noon_estimate_without_changing_user_data(client):
    http, app, calls, _ = client
    body = {"profile": {**PROFILE, "birth_time": None}, "year": 2027}
    response = http.post("/api/life-reports", json=body, headers=HEADERS)
    assert response.status_code == 200, response.text
    result = response.json()
    assert result["preview_state"] == "ready"
    assert result["input"]["profile"]["birth_time"] is None
    assert result["time_accuracy"] == {"mode": "estimated", "assumed_local_time": "12:00"}
    assert calls[0]["birth_time_basis"] == result["time_accuracy"]
    assert all(fact["time_estimated"] for fact in calls[0]["evidence"].values())
    assert all("12:00" in fact["detail"] for fact in result["preview"]["summary"]["evidence"])
    with app.state.store.connect() as db:
        stored = json.loads(db.execute("SELECT chart FROM life_reports WHERE id=?", (result["id"],)).fetchone()[0])
    assert stored["time_known"] is False
    assert stored["calculation_input"]["time_precision"] == "estimated-noon"
    assert "T12:00" in stored["calculation_input"]["local_datetime"]
    assert http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS).status_code == 200
    finish(http, app)
    full = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert full["full_state"] == "ready" and len(full["chapters"]) == 5
    assert full["input"]["profile"]["birth_time"] is None
    assert all(bundle["birth_time_basis"]["mode"] == "estimated" for bundle in calls)
    exact = http.post("/api/life-reports", json={**body, "profile": {**PROFILE, "birth_time": "12:00"}}, headers=HEADERS).json()
    assert exact["id"] != result["id"]
    assert exact["time_accuracy"]["mode"] == "exact"
    finish(http, app)


def test_failed_chapters_are_saved_and_resume_without_regenerating_finished_ones(client):
    http, app, calls, mode = client
    result = preview(http)
    mode["fail"] = "love"
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    partial = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert partial["full_state"] == "unavailable"
    assert {row["key"] for row in partial["chapters"]} == {"work", "money", "family", "annual"}
    assert partial["progress"] == {"completed": 3, "total": 5} and partial["plan"] is None
    mode["fail"] = None
    with app.state.store.connect() as db:
        db.execute("UPDATE bazi_reports SET retry_after=0")
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    assert http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()["full_state"] == "ready"
    assert sum(row["reading"] == "money" for row in calls) == 1
    assert sum(row["reading"] == "annual" for row in calls) == 1
    assert sum(row["reading"] == "love" for row in calls) == 2


def test_parallel_chapters_keep_the_lease_alive_and_save_every_completed_topic(client, monkeypatch):
    http, app, _, _ = client
    service = app.state.life_reports
    service.lease_seconds = 0.18
    service.heartbeat_seconds = 0.02
    release, started = asyncio.Event(), asyncio.Event()
    active = maximum = 0

    async def write(self, bundle, **kwargs):
        nonlocal active, maximum
        if bundle["stage"] == "chapter":
            active += 1
            maximum = max(maximum, active)
            if active == 3:
                started.set()
            try:
                await release.wait()
            finally:
                active -= 1
        return self.validate(json.dumps(story_for(bundle), ensure_ascii=False), bundle)

    monkeypatch.setattr(LifeWriter, "write", write)
    result = preview(http)
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)

    async def observe():
        app.state.life_report_gate.set()
        await asyncio.wait_for(started.wait(), 2)
        await asyncio.sleep(0.24)
        with service.store.connect() as db:
            row = db.execute("SELECT full_state,lease_until FROM life_reports WHERE id=?", (result["id"],)).fetchone()
        assert row["full_state"] == "generating" and row["lease_until"] > time.time()
        assert active == 3
        release.set()

    http.portal.call(observe)
    finish(http, app)
    full = http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS).json()
    assert maximum == 3 and full["full_state"] == "ready"
    assert [row["key"] for row in full["chapters"]] == ["work", "money", "love", "family", "annual"]
    assert full["progress"] == {"completed": 5, "total": 5}


def test_common_borrowed_terms_do_not_reject_chinese_but_wrong_language_is_still_repaired():
    for text in ("共同聚餐时，可以先说好采用AA制，避免事后猜测对方的期待。", "可以用记账APP或Excel记录共同支出，再把各自承担的部分核对清楚。", "如果自己未想清楚，可以先列出3项需要，再考虑未来三年的长期安排。", "今年可以先明确自己愿意投入哪些工作，再决定如何安排精力。"):
        validate_text(text, "zh")
    with pytest.raises(InvalidBaziReport) as error:
        validate_text("不要因为FOMO就立刻答应额外支出，先核对已经安排好的用途。", "zh")
    assert "FOMO" in error.value.feedback and "replace foreign words" in error.value.feedback
    assert "额外支出" not in error.value.feedback
    with pytest.raises(InvalidBaziReport):
        validate_text("Review the budget before agreeing to a purchase.", "zh")
    for text in ("你的己未日柱说明你很擅长管理共同支出。", "到了2027年，你的工作和收入一定会获得提升。", "到了三月，你的工作和收入一定会获得提升。"):
        with pytest.raises(InvalidBaziReport):
            validate_text(text, "zh")


def test_writer_rejects_thin_or_misleading_evidence_and_short_traits(client):
    http, _, calls, _ = client
    preview(http)
    bundle = calls[0]
    for kind in ("unknown", "thin", "short", "trait", "calculation"):
        story = story_for(bundle)
        trait = story["traits"][0]
        if kind == "unknown":
            trait["evidence_ids"] = ["H1", "MADE_UP"]
        elif kind == "thin":
            trait["evidence_ids"] = ["H1", "H5"]
        elif kind == "short":
            trait["text"] = "你很有优势，只要保持平衡就能做好事情。"
        elif kind == "trait":
            story["traits"][2]["evidence_ids"] = ["H1", "P_sun"]
        else:
            trait["text"] = TRAIT + "你的第十宫落有太阳。"
        with pytest.raises(InvalidBaziReport):
            validate_life_story(json.dumps(story, ensure_ascii=False), bundle)


def test_chinese_preview_allows_a_trait_over_the_old_limit(client):
    http, _, calls, _ = client
    preview(http)
    bundle = calls[0]
    story = story_for(bundle)
    trait = story["traits"][0]
    text = trait["text"]
    length = sum("\u3400" <= char <= "\u9fff" for char in text)

    trait["text"] = text + "稳" * (173 - length)
    assert validate_life_story(json.dumps(story, ensure_ascii=False), bundle)["traits"][0]["text"] == trait["text"]

    trait["text"] += "稳" * 8
    with pytest.raises(InvalidBaziReport, match="shorten above 180"):
        validate_life_story(json.dumps(story, ensure_ascii=False), bundle)


def test_cached_model_contract_can_be_revalidated(client):
    http, _, calls, _ = client
    preview(http)
    validated = validate_life_story(json.dumps(story_for(calls[0]), ensure_ascii=False), calls[0])
    assert validated["translations"] == {}
    assert validate_life_story(json.dumps(validated, ensure_ascii=False), calls[0]) == validated


def test_preview_repairs_all_mismatched_trait_citations_together(client, monkeypatch):
    http, _, _, _ = client
    attempts = []
    async def write(self, bundle, *, correction=None):
        attempts.append(correction)
        story = story_for(bundle)
        if correction is None:
            story["traits"][1]["evidence_ids"] = ["H5", "P_sun"]
            story["traits"][2]["evidence_ids"] = ["H1", "P_sun"]
            raw = json.dumps(story, ensure_ascii=False)
            try:
                return self.validate(raw, bundle)
            except InvalidBaziReport as error:
                error.candidate = raw
                raise
        feedback = correction["feedback"]
        assert "traits[decisions].evidence_ids=['H5', 'P_sun']" in feedback
        assert "['H1', 'H9', 'H10']" in feedback
        assert "traits[relationships].evidence_ids=['H1', 'P_sun']" in feedback
        assert "['H7', 'H4']" in feedback
        assert "rewrite this trait's text" in feedback
        return self.validate(json.dumps(story, ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    result = preview(http)
    assert result["preview_state"] == "ready" and len(attempts) == 2
    assert result["preview"]["traits"][1]["evidence"][0]["id"] == "H9"


def test_one_complete_report_fits_the_default_six_run_budget(client):
    http, app, calls, _ = client
    app.state.life_reports.writer.settings.bazi_reports_per_minute = 6
    result = preview(http)
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    assert http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()["full_state"] == "ready"
    assert len(calls) == 7
    with app.state.store.connect() as db:
        counts = db.execute("SELECT COUNT(*) FROM bazi_report_usage GROUP BY scope").fetchall()
    assert [row[0] for row in counts] == [2, 2]


def test_unlimited_testing_allows_preview_and_full_report_after_shared_network_quota(client):
    http, app, calls, _ = client
    settings = app.state.life_reports.writer.settings
    settings.bazi_reports_per_minute = settings.bazi_reports_per_day = 0
    network = "network:" + app.state.store.hash("testclient")
    with app.state.store.connect() as db:
        db.executemany("INSERT INTO bazi_report_usage VALUES(?,?)", [(network, time.time())] * 100)
    result = preview(http)
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    assert http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()["full_state"] == "ready"
    assert len(calls) == 7


@pytest.mark.parametrize("model", ["test", "qwen3.7-plus"])
def test_provider_usage_is_scoped_to_preview_full_and_repairs_without_charging_cached_views(client, monkeypatch, model):
    http, app, _, _ = client
    app.state.life_reports.writer.config.model = model
    real_client = httpx.AsyncClient
    model_calls = []

    def handler(request):
        payload = json.loads(request.content)
        assert payload["stream_options"] == {"include_usage": True}
        bundle = json.loads(payload["messages"][1]["content"])
        if model == "qwen3.7-plus":
            assert payload["response_format"]["type"] == "json_schema"
            schema = payload["response_format"]["json_schema"]["schema"]
            assert schema["properties"]["language"]["const"] == bundle["language"]
            assert schema["properties"]["reading"]["const"] == bundle["reading"]
            assert "translations" not in schema["properties"] and not schema["additionalProperties"]
            if bundle["stage"] == "chapter":
                assert {"example", "response"} <= set(schema["$defs"]["Insight"]["required"])
                ids = schema["$defs"]["Insight"]["properties"]["evidence_ids"]
                assert ids["minItems"] == ids["maxItems"] == 2
                assert set(ids["items"]["enum"]) == set(bundle["evidence"])
            elif bundle["stage"] == "plan":
                assert set(schema["$defs"]["Phase"]["properties"]["action_ids"]["items"]["enum"]) == set(bundle["source_actions"])
        else:
            assert payload["response_format"] == {"type": "json_object"}
        schemas = [line for line in payload["messages"][0]["content"].splitlines() if line.startswith("stage=")]
        assert len(schemas) == 1 and schemas[0].startswith(f"stage={bundle['stage']}:")
        model_calls.append(bundle["stage"])
        story = story_for(bundle)
        if len(model_calls) == 1:
            story["traits"][0]["evidence_ids"] = ["H99", "P_sun"]
        packets = [
            {"choices": [{"delta": {"content": json.dumps(story, ensure_ascii=False)}, "finish_reason": "stop"}]},
            {"choices": [], "id": f"synthetic-usage-{len(model_calls)}",
             "usage": {"prompt_tokens": 100, "completion_tokens": 50, "prompt_tokens_details": {"cached_tokens": 20}}},
        ]
        return httpx.Response(200, headers={"content-type": "text/event-stream"},
                              text="".join("data: " + json.dumps(packet, ensure_ascii=False) + "\n\n" for packet in packets) + "data: [DONE]\n\n")

    monkeypatch.setattr(LifeWriter, "write", BaziReports.write)
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    result = preview(http)
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    assert http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()["full_state"] == "ready"
    with app.state.store.connect() as db:
        rows = db.execute("SELECT * FROM report_model_usage ORDER BY id").fetchall()
    assert len(rows) == len(model_calls) == 8
    assert {row["report_id"] for row in rows} == {result["id"]}
    assert [row["phase"] for row in rows] == ["preview"] * 2 + ["full"] * 6
    assert [row["validated"] for row in rows] == [0] + [1] * 7
    assert all((row["prompt_tokens"], row["completion_tokens"], row["cached_tokens"], row["usage_received"]) == (100, 50, 20, 1) for row in rows)
    assert preview(http)["id"] == result["id"]
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    assert len(model_calls) == 8


def test_concurrent_identical_previews_share_one_preview_without_starting_paid_work(client):
    http, app, calls, _ = client
    app.state.life_reports.writer.settings.bazi_reports_per_minute = 6
    body = LifeInput(profile=PROFILE, year=2027)
    async def create_together():
        return await asyncio.gather(*(app.state.life_reports.create(body, "same-owner", "same-network") for _ in range(6)))
    results = http.portal.call(create_together)
    assert len({row["id"] for row in results}) == 1
    assert all(row["preview_state"] == "ready" for row in results)
    assert len(calls) == 1
    with app.state.store.connect() as db:
        counts = db.execute("SELECT COUNT(*) FROM bazi_report_usage GROUP BY scope").fetchall()
    assert [row[0] for row in counts] == [1, 1]


def test_thai_preview_chapters_and_plan_use_the_same_validated_pipeline(client, monkeypatch):
    http, app, calls, _ = client
    body = "เมื่อสิ่งที่ต้องทำยังไม่ชัด คุณอาจอยากคุยให้เข้าใจตรงกันก่อนเริ่ม ลองถามว่าผลงานแบบไหนที่ต้องการ แล้วเลือกส่วนเล็กมาลองทำก่อน วิธีนี้ช่วยให้เตรียมตัวได้ แต่หากต้องเริ่มทดลองเร็ว อาจตกลงขอบเขตสั้น ๆ แล้วค่อยปรับจากสิ่งที่พบ หลังจากลองทำให้ทบทวนว่าวิธีไหนช่วยลดความสับสน และเก็บส่วนที่ได้ผลไว้ใช้ต่อไป"
    topics = {"overview": "ชีวิต", "money": "การเงิน", "work": "การทำงาน", "love": "การพูดคุย", "family": "ครอบครัว", "annual": "การเตรียมตัว", "life-preview": "นิสัย", "life-plan": "การลงมือ"}
    async def write(self, bundle, **kwargs):
        calls.append(deepcopy(bundle))
        story = story_for(bundle)
        counter = 0
        def translate(value, field=""):
            nonlocal counter
            if isinstance(value, dict):
                if field == "summary":
                    return {**value, "text": "สื่อสารความต้องการให้ชัดก่อนเลือกสิ่งที่คุณทุ่มเท"}
                return {key: translate(item, key) for key, item in value.items()}
            if isinstance(value, list):
                if field in ("evidence_ids", "action_ids"):
                    return value
                return [translate(item, field) for item in value]
            if isinstance(value, str) and field not in ("language", "reading", "key"):
                counter += 1
                prefix = topics[bundle["reading"]] + chr(0x0E01 + counter % 35)
                return prefix + ("เลือกวิธีที่เหมาะกับคุณ" if field == "title" else body)
            return value
        return self.validate(json.dumps(translate(story), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    response = http.post("/api/life-reports", json={"profile": {**PROFILE, "language": "th"}, "year": 2027}, headers=HEADERS)
    result = response.json()
    assert result["preview_state"] == "ready", result
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    full = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert full["full_state"] == "ready" and len(full["chapters"]) == 5
    assert full["plan"] and full["title"] == "คำอ่านดวงออนไลน์"


def test_life_writer_can_correct_two_different_validation_issues_in_one_run(client, monkeypatch):
    http, _, _, _ = client
    attempts = []
    async def write(self, bundle, **kwargs):
        attempts.append(kwargs.get("correction"))
        if len(attempts) < 3:
            error = InvalidBaziReport("synthetic validation issue")
            error.candidate = "{}"
            raise error
        return self.validate(json.dumps(story_for(bundle), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    result = preview(http)
    assert result["preview_state"] == "ready"
    assert len(attempts) == 3 and attempts[0] is None
    assert attempts[1]["draft"] == "{}" and attempts[2]["draft"] == "{}"


def test_draft_field_progress_does_not_count_unfinished_or_unexpected_values():
    assert writing_progress('{"summary":{"text":"unfinished', "chapter") == 0
    first = writing_progress('{"summary":{"text":"completed"},"insights":[{"title":"ready"', "chapter")
    later = writing_progress('{"summary":{"text":"completed"},"insights":[{"title":"ready","text":"written","example":"example"', "chapter")
    assert 0 < first < later < 100
    assert writing_progress('{"unknown":"does not count"}', "chapter") == 0
    assert writing_progress('{"actions":[{"steps":"not a list of completed steps"}]}', "chapter") == 0
    assert writing_progress('{"watchpoints":[{"signals":"not a list"}]}', "chapter") == 0
    assert writing_progress('{"phases":[{"action_ids":"work:0"}]}', "plan") == 0


def test_streamed_fields_update_live_progress_before_any_chapter_is_complete(client, monkeypatch):
    http, app, _, _ = client
    real_client = httpx.AsyncClient
    paused, release = asyncio.Event(), asyncio.Event()
    waiting = set()

    class StoryStream(httpx.AsyncByteStream):
        def __init__(self, bundle):
            self.bundle = bundle

        async def __aiter__(self):
            raw = json.dumps(story_for(self.bundle), ensure_ascii=False)
            threshold = raw.find('"watchpoints"')
            held = False
            for offset in range(0, len(raw), 64):
                packet = {"choices": [{"delta": {"content": raw[offset:offset + 64]}, "finish_reason": None}]}
                yield ("data: " + json.dumps(packet, ensure_ascii=False) + "\n\n").encode()
                if not held and self.bundle["stage"] == "chapter" and self.bundle["reading"] in {"work", "money", "love"} and offset >= threshold:
                    held = True
                    waiting.add(self.bundle["reading"])
                    if len(waiting) == 3:
                        paused.set()
                    await release.wait()
            yield b'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n'

    def handler(request):
        bundle = json.loads(json.loads(request.content)["messages"][1]["content"])
        return httpx.Response(200, headers={"Content-Type": "text/event-stream"}, stream=StoryStream(bundle))

    monkeypatch.setattr(LifeWriter, "write", BaziReports.write)
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    result = preview(http)
    assert result["full_state"] == "not_started" and result["generation_progress"]["percent"] == 0
    assert not waiting
    unlocked = http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS).json()
    assert unlocked["full_state"] == "generating"

    async def observe():
        app.state.life_report_gate.set()
        await asyncio.wait_for(paused.wait(), 3)
    http.portal.call(observe)
    partial = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert partial["progress"] == {"completed": 0, "total": 5}
    assert 1 <= partial["generation_progress"]["percent"] < 20
    assert len([section for section in partial["generation_progress"]["sections"] if section["percent"] > 0]) == 3
    assert not partial["chapters"] and partial["plan"] is None
    http.portal.call(release.set)
    finish(http, app)
    complete = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert complete["full_state"] == "ready" and complete["generation_progress"]["percent"] == 100


def test_free_progress_counts_characters_inside_an_unfinished_text_field():
    first = preview_writing_progress('{"summary":{"text":"' + "实" * 12, "zh")
    second = preview_writing_progress('{"summary":{"text":"' + "实" * 24, "zh")
    assert 0 < first["preview_summary"] < second["preview_summary"] < 99
    assert sum(first.values()) // 4 < sum(second.values()) // 4
    closed = preview_writing_progress('{"summary":{"text":"已经完整接收的摘要"}}', "zh")
    assert closed["preview_summary"] == 99
    assert not any(preview_writing_progress('{"summary":{"text":123},"traits":"wrong type"}', "zh").values())


def test_async_free_report_returns_early_and_streams_progress_without_paid_work(client, monkeypatch):
    http, app, _, _ = client
    real_client = httpx.AsyncClient
    first, second, release_first, release_second = (asyncio.Event() for _ in range(4))
    calls = []

    class PreviewStream(httpx.AsyncByteStream):
        async def __aiter__(self):
            raw = json.dumps(story_for(calls[0]), ensure_ascii=False)
            start = raw.index('"text": "') + len('"text": "')
            cuts = [start + 12, start + 24, len(raw)]
            offset = 0
            for index, end in enumerate(cuts):
                packet = {"choices": [{"delta": {"content": raw[offset:end]}, "finish_reason": None}]}
                yield ("data: " + json.dumps(packet, ensure_ascii=False) + "\n\n").encode()
                offset = end
                if index == 0:
                    first.set()
                    await release_first.wait()
                elif index == 1:
                    second.set()
                    await release_second.wait()
            yield b'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n'

    def handler(request):
        bundle = json.loads(json.loads(request.content)["messages"][1]["content"])
        assert bundle["stage"] == "preview"
        calls.append(bundle)
        return httpx.Response(200, headers={"Content-Type": "text/event-stream"}, stream=PreviewStream())

    monkeypatch.setattr(LifeWriter, "write", BaziReports.write)
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    body = {"profile": PROFILE, "year": 2027}
    response = http.post("/api/life-reports?wait=false", json=body, headers=HEADERS)
    assert response.status_code == 200
    result = response.json()
    assert result["preview"] is None and result["preview_state"] == "generating"
    http.portal.call(first.wait)
    initial = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    percent = initial["preview_generation_progress"]["percent"]
    assert 0 < percent < 25 and initial["preview"] is None
    again = http.post("/api/life-reports?wait=false", json=body, headers=HEADERS).json()
    assert again["id"] == result["id"] and len(calls) == 1
    http.portal.call(release_first.set)
    http.portal.call(second.wait)
    later = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert percent < later["preview_generation_progress"]["percent"] < 25
    assert later["preview"] is None and later["full_state"] == "not_started"
    http.portal.call(release_second.set)

    async def finish_preview():
        await asyncio.gather(*list(app.state.life_reports.preview_tasks.values()))
    http.portal.call(finish_preview)
    done = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert done["preview_state"] == "ready" and done["preview_generation_progress"]["percent"] == 100
    assert done["full_state"] == "not_started" and not app.state.life_reports.tasks
    assert len(calls) == 1


def test_expired_preview_snapshot_does_not_clear_a_lease_renewed_before_update(client, monkeypatch):
    http, app, _, _ = client
    result = preview(http)
    service = app.state.life_reports
    service.update(result["id"], preview=None, preview_state="generating", lease="renewed-preview", lease_until=time.time() - 1)
    original = service.row
    renewed = False

    def row_and_renew(report_id, owner):
        nonlocal renewed
        row = original(report_id, owner)
        if not renewed:
            renewed = True
            service.update(report_id, expected_lease="renewed-preview", lease_until=time.time() + 60)
        return row

    monkeypatch.setattr(service, "row", row_and_renew)
    snapshot = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert snapshot["preview_state"] == "generating"
    with service.store.connect() as db:
        row = db.execute("SELECT lease,lease_until FROM life_reports WHERE id=?", (result["id"],)).fetchone()
    assert row["lease"] == "renewed-preview" and row["lease_until"] > time.time()
