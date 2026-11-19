"""Synthetic model output exercises the real chart, transport and persistence."""
import asyncio
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
import json
import re
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
TOPICS = {"overview": "生活", "money": "收入", "work": "工作", "love": "相处", "family": "家庭", "annual": "安排",
          "overall": "取舍", "pattern": "优势", "marriage": "经营", "wealth": "积累", "risk": "留意", "romance": "相识"}


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


def thai_story_for(bundle):
    body = "เมื่อสิ่งที่ต้องทำยังไม่ชัด คุณอาจอยากคุยให้เข้าใจตรงกันก่อนเริ่ม ลองถามว่าผลงานแบบไหนที่ต้องการ แล้วเลือกส่วนเล็กมาลองทำก่อน วิธีนี้ช่วยให้เตรียมตัวได้ แต่หากต้องเริ่มทดลองเร็ว อาจตกลงขอบเขตสั้น ๆ แล้วค่อยปรับจากสิ่งที่พบ หลังจากลองทำให้ทบทวนว่าวิธีไหนช่วยลดความสับสน และเก็บส่วนที่ได้ผลไว้ใช้ต่อไป"
    topics = {"overview": "ชีวิต", "money": "การเงิน", "work": "การทำงาน", "love": "การพูดคุย", "family": "ครอบครัว",
              "annual": "การเตรียมตัว", "life-preview": "นิสัย", "life-plan": "การลงมือ", "overall": "ภาพรวม",
              "pattern": "จุดแข็ง", "marriage": "ชีวิตคู่", "wealth": "รายได้", "risk": "เรื่องที่ควรระวัง", "romance": "ความรัก"}
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

    return translate(story_for(bundle))


@pytest.fixture
def client(postgres_url, monkeypatch):
    calls = []
    mode = {"fail": None}
    async def write(self, bundle, **kwargs):
        calls.append(deepcopy(bundle))
        if bundle["stage"] == "chapter" and bundle["reading"] == mode["fail"]:
            raise InvalidBaziReport("synthetic unavailable")
        return self.validate(json.dumps(story_for(bundle), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    settings = Settings(database_url=postgres_url, app_env="production", providers={"qwen": ProviderConfig("test-key", "https://model.example/v1", "test")}, bazi_reports_per_minute=100, bazi_reports_per_day=100)
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
        async with asyncio.timeout(20):
            while True:
                with app.state.store.connect() as db:
                    active = db.execute("SELECT 1 FROM life_reports WHERE unlocked=1 AND preview IS NOT NULL "
                                        "AND full_state IN ('queued','pending','generating') LIMIT 1").fetchone()
                if not active:
                    return
                await asyncio.sleep(0.05)
    http.portal.call(wait)


def test_preview_is_personal_and_does_not_return_paid_chapters(client):
    http, _, calls, _ = client
    result = preview(http)
    assert result["title"] == "人生报告"
    assert len(result["preview"]["traits"]) == 3 and len(result["catalog"]) == 5
    assert result["chapters"] == [] and result["plan"] is None
    assert result["access"] == "preview" and result["price"]["mode"] == "direct"
    assert "birth_date" not in json.dumps(calls[0])
    assert all(len(row["evidence"]) == 2 for row in result["preview"]["traits"])
    assert preview(http)["id"] == result["id"] and len(calls) == 1


def test_fortune_topics_unlock_with_distinct_evidence_and_content_progress(client):
    http, app, calls, _ = client
    legacy = preview(http)
    response = http.post("/api/life-reports", json={"profile": PROFILE, "year": 2027, "report_kind": "fortune"}, headers=HEADERS)
    assert response.status_code == 200, response.text
    report = response.json()
    keys = ["annual", "overall", "pattern", "marriage", "wealth", "risk", "romance"]
    assert report["id"] != legacy["id"] and report["title"] == "运程解析"
    assert report["version"] == "fortune-reading-1"
    assert [item["key"] for item in report["catalog"]] == keys
    assert report["catalog"][0]["title"] == "2027年运程"
    assert report["chapters"] == [] and report["plan"] is None
    assert len(calls) == 2 and not app.state.life_reports.tasks
    unlocked = http.post(f"/api/life-reports/{report['id']}/unlock", json={}, headers=HEADERS).json()
    assert unlocked["progress"] == {"completed": 0, "total": 8}
    with app.state.life_reports.store.connect() as db:
        lease = db.execute("SELECT lease FROM life_reports WHERE id=%s", (report["id"],)).fetchone()["lease"]
    app.state.life_reports.record_progress(report["id"], lease, {"annual": 25, "overall": 50})
    partial = http.get(f"/api/life-reports/{report['id']}", headers=HEADERS).json()
    assert partial["generation_progress"]["percent"] == 9
    assert partial["preview_generation_progress"]["percent"] == 100
    assert partial["chapters"] == []
    finish(http, app)
    full = http.get(f"/api/life-reports/{report['id']}", headers=HEADERS).json()
    assert full["full_state"] == "ready", full
    assert [chapter["key"] for chapter in full["chapters"]] == keys
    assert full["progress"] == {"completed": 8, "total": 8}
    assert full["generation_progress"]["percent"] == 100 and full["plan"]
    bundles = {bundle["reading"]: bundle for bundle in calls if bundle["stage"] == "chapter"}
    assert bundles["risk"]["topic_evidence"] == ["H6", "H8", "H12"]
    assert bundles["marriage"]["topic_evidence"] == ["H4", "H7", "H8"]
    assert bundles["romance"]["topic_evidence"] == ["H1", "H5", "H7", "H11"]
    assert {fact["month"] for key, fact in bundles["annual"]["evidence"].items() if key.startswith("M")} == set(range(1, 13))
    for key in keys:
        assert app.state.life_reports.parts_writer.prompt(bundles[key])
    assert preview(http)["id"] == legacy["id"]
    count = len(calls)
    assert http.post(f"/api/life-reports/{report['id']}/unlock", json={}, headers=HEADERS).json()["full_state"] == "ready"
    assert len(calls) == count


def test_fortune_retry_keeps_the_six_successful_topics(client):
    http, app, calls, mode = client
    mode["fail"] = "risk"
    report = http.post("/api/life-reports", json={"profile": PROFILE, "year": 2027, "report_kind": "fortune"}, headers=HEADERS).json()
    http.post(f"/api/life-reports/{report['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    partial = http.get(f"/api/life-reports/{report['id']}", headers=HEADERS).json()
    assert partial["full_state"] == "unavailable"
    assert {item["key"] for item in partial["chapters"]} == {"annual", "overall", "pattern", "marriage", "wealth", "romance"}
    assert partial["generation_progress"]["percent"] < 100 and partial["plan"] is None
    done = {key: sum(bundle["reading"] == key for bundle in calls) for key in ("annual", "overall", "pattern", "marriage", "wealth", "romance")}
    mode["fail"] = None
    http.post(f"/api/life-reports/{report['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    full = http.get(f"/api/life-reports/{report['id']}", headers=HEADERS).json()
    assert full["full_state"] == "ready" and len(full["chapters"]) == 7
    assert all(sum(bundle["reading"] == key for bundle in calls) == count for key, count in done.items())
def test_simulated_checkout_requires_the_owned_order_before_unlock(client, monkeypatch):
    http, app, _, _ = client
    monkeypatch.setattr(app.state.life_reports, "development", True)
    report = preview(http)
    assert report["payment_simulation"] is True
    path = f"/api/life-reports/{report['id']}"
    assert http.post(f"{path}/unlock", headers=HEADERS).status_code == 402
    created = http.post(f"{path}/payment", headers=HEADERS)
    assert created.status_code == 200
    order = created.json()
    assert order["amount"] == report["price"]["amount"] == 3000
    assert report["price"]["display"] == "฿30"
    assert order["reference"] == "000000000001"
    assert order["currency"] == "THB"
    assert http.post(f"{path}/payment", headers=HEADERS).json() == order
    assert http.post(f"{path}/payment/check", headers=HEADERS).json() == {"paid": False}
    assert http.post(f"{path}/unlock", headers=HEADERS).status_code == 402

    confirm = f"{path}/payment/simulate"
    payload = {"reference": order["reference"]}
    assert http.post(confirm, headers={"X-Report-Key": "z" * 48}, json=payload).status_code == 404
    assert http.post(confirm, headers=HEADERS, json={"reference": "000000000000"}).status_code == 409
    with monkeypatch.context() as production:
        production.setattr(app.state.life_reports, "development", False)
        assert http.post(confirm, headers=HEADERS, json=payload).status_code == 404
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"

    assert http.post(confirm, headers=HEADERS, json=payload).json() == {"paid": True}
    assert http.post(confirm, headers=HEADERS, json=payload).json() == {"paid": True}
    assert http.post(f"{path}/payment/check", headers=HEADERS).json() == {"paid": True}
    finish(http, app)
    ready = http.get(path, headers=HEADERS).json()
    assert ready["access"] == "full" and ready["full_state"] == "ready"


def sunlands_order_only(app, monkeypatch, handler):
    payments = app.state.life_reports.card_payments
    settings = Settings(sunlands_order_only=True, sunlands_app_secret="integration-test-secret",
                        sunlands_province_id="4")
    monkeypatch.setattr(payments, "settings", settings)
    monkeypatch.setattr(payments, "order_only", True)
    original_client = httpx.AsyncClient
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: original_client(
        **kwargs, transport=httpx.MockTransport(handler)))
    return payments


@pytest.fixture
def sunlands_phone_response():
    return json.dumps({"flag": "1", "data": {
        "isSuccess": True, "channelCode": "sunlands_fb_fate", "currency": "THB",
        "orderNumber": "OFFLINE_PHONE_ORDER_001", "stuId": 12345, "totalAmount": 10.0,
        "orderStatus": "UNPAID", "paidupAmount": 0.0, "orderType": "OVERSEAS_NORMAL",
        "payDirectUrl": "http://trade.sunlands.com/trade/web/trade/payDirect.action?orderNumber=OFFLINE_PHONE_ORDER_001&termType=mobile&tradeType=WX_MWEB",
        "orderDetails": [{"itemNo": "193261112000101", "itemPrice": 10.0,
                          "subSerialNo": "OFFLINE_PHONE_ORDER_001_1"}],
    }}).encode()


def test_sunlands_data_envelope_persists_order_without_pay_number(client, monkeypatch, sunlands_phone_response, record_property):
    import hashlib
    from backend.app.life_card_payments import LifeCardPayments

    http, app, _, _ = client
    expected = json.loads(sunlands_phone_response)["data"]
    calls = []
    def upstream(request):
        assert request.method == "POST" and request.url.path == "/tradeApi/trade/externalCreateOrder"
        calls.append(request)
        return httpx.Response(200, content=sunlands_phone_response, headers={"content-type": "application/json"})
    payments = sunlands_order_only(app, monkeypatch, upstream)
    report = preview(http)
    path = f"/api/life-reports/{report['id']}"
    contact = {"mobile": "13000000000", "nationCode": "86"}
    assert http.get(path + "/payment", headers=HEADERS).status_code == 204
    assert not calls and payments.order_for(report["id"]) is None
    response = http.post(path + "/payment", headers=HEADERS, json=contact)
    assert response.status_code == 200, response.text
    order = response.json()
    assert order["state"] == "CREATED" and order["order_only"] is True
    assert order["order_number"] == expected["orderNumber"] and order["stu_id"] == str(expected["stuId"])
    assert order["pay_number"] is None and order["amount"] == 1000 and order["currency"] == "THB"
    assert "payDirectUrl" not in order
    assert order["checkout_url"] == expected["payDirectUrl"]
    restarted = LifeCardPayments(payments.store, payments.settings)
    monkeypatch.setattr(app.state.life_reports, "card_payments", restarted)
    assert http.get(path + "/payment", headers=HEADERS).json() == order
    assert http.get(path + "/payment", headers={"X-Report-Key": "z" * 48}).status_code == 404
    assert http.post(path + "/payment", headers=HEADERS, json=contact).json() == order
    assert http.post(path + "/payment", headers={"X-Report-Key": "z" * 48}, json=contact).status_code == 404
    saved = restarted.order_for(report["id"])
    receipt = json.loads(saved["sunlands_order"])
    assert saved["sunlands_order_number"] == expected["orderNumber"] and saved["sunlands_pay_number"] is None
    assert saved["report_id"] == report["id"] and saved["provider_order"] is None
    assert receipt["stuId"] == str(expected["stuId"])
    assert receipt["attempts"][0]["orderNumber"] == expected["orderNumber"]
    assert receipt["attempts"][0]["stuId"] == str(expected["stuId"])
    assert receipt["responseSummary"]["flag"] == "1" and receipt["responseSummary"]["isSuccess"] == "True"
    assert receipt["responseSummary"]["orderStatus"] == "UNPAID"
    assert receipt["responseHash"] == hashlib.sha256(sunlands_phone_response).hexdigest()
    assert app.state.life_reports.card_payments.order_for(report["id"])["provider_order"] is None
    assert http.post(path + "/payment/simulate", headers=HEADERS, json={"reference": order["reference"]}).status_code == 404
    assert http.post(path + "/unlock", headers=HEADERS).status_code == 402
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"
    assert len(calls) == 1 and len(receipt["attempts"]) == 1
    record_property("offline_evidence", json.dumps({
        "source": "Response bytes replayed through MockTransport; no external request",
        "response_sha256": receipt["responseHash"], "local_response": order,
        "report_id": report["id"], "persisted_order_number": saved["sunlands_order_number"],
        "persisted_stu_id": receipt["stuId"], "mock_request_count": len(calls),
        "report_access": "preview", "paid": False,
    }, ensure_ascii=False))


@pytest.mark.parametrize("checkout_url", [
    "https://untrusted.example/trade/web/trade/payDirect.action?orderNumber=OFFLINE_PHONE_ORDER_001",
    "https://trade.sunlands.com/trade/web/trade/payDirect.action?orderNumber=ANOTHER_ORDER",
    "http://trade.sunlands.com/trade/web/trade/payDirect.action?orderNumber=OFFLINE_PHONE_ORDER_001&orderNumber=",
    "javascript:alert(1)",
])
def test_sunlands_existing_order_hides_invalid_cashier_without_creating_again(client, monkeypatch, sunlands_phone_response, checkout_url):
    http, app, _, _ = client
    result = json.loads(sunlands_phone_response)
    result["data"]["payDirectUrl"] = checkout_url
    calls = []
    def upstream(request):
        calls.append(request)
        return httpx.Response(200, json=result)
    payments = sunlands_order_only(app, monkeypatch, upstream)
    report = preview(http)
    path = f"/api/life-reports/{report['id']}"
    created = http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"})
    assert created.status_code == 200 and created.json()["checkout_url"] is None
    receipt = payments.order_for(report["id"])["sunlands_order"]
    assert http.get(path + "/payment", headers=HEADERS).json() == created.json()
    assert payments.order_for(report["id"])["sunlands_order"] == receipt
    assert len(calls) == 1 and http.get(path, headers=HEADERS).json()["access"] == "preview"


@pytest.mark.parametrize("outcome", ("gateway_failure", "invalid_data", "business_rejected",
                                    "wrong_currency", "missing_student", "invalid_pay_number"))
def test_sunlands_data_envelope_failure_is_saved_without_retry(client, monkeypatch, sunlands_phone_response, outcome):
    http, app, _, _ = client
    result = json.loads(sunlands_phone_response)
    if outcome == "gateway_failure":
        result["flag"] = "0"
    elif outcome == "invalid_data":
        result.update(result["data"])
        result["data"] = None
    elif outcome == "business_rejected":
        result["data"].update(isSuccess=False, errorMsg="declined 13000000000 integration-test-secret")
    elif outcome == "wrong_currency":
        result["data"]["currency"] = "USD"
    elif outcome == "missing_student":
        result["data"].pop("stuId")
    else:
        result["data"]["payNumber"] = "invalid pay number"
    calls = []
    def upstream(request):
        calls.append(request)
        return httpx.Response(200, json=result)
    payments = sunlands_order_only(app, monkeypatch, upstream)
    report = preview(http)
    path = f"/api/life-reports/{report['id']}"
    for _ in range(2):
        response = http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"})
        assert response.status_code == 409
        assert response.json()["code"] == ("life_order_rejected" if outcome == "business_rejected" else "life_order_needs_review")
    receipt = json.loads(payments.order_for(report["id"])["sunlands_order"])
    assert receipt["state"] == ("REJECTED" if outcome == "business_rejected" else "UNKNOWN")
    assert len(receipt["attempts"]) == 1 and len(calls) == 1
    if outcome != "invalid_data":
        assert receipt["orderNumber"] == result["data"]["orderNumber"]
    assert "13000000000" not in json.dumps(receipt) and "integration-test-secret" not in json.dumps(receipt)
    assert app.state.life_reports.card_payments.order_for(report["id"])["provider_order"] is None
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"


def test_sunlands_channel_environment_distinguishes_unset_from_empty(monkeypatch):
    from backend.app import config
    monkeypatch.setattr(config, "load_dotenv", lambda: None)
    monkeypatch.delenv("SUNLANDS_CHANNEL_CODE", raising=False)
    assert Settings.from_env().sunlands_channel_code is None
    for value in ("", "offline_test_channel"):
        monkeypatch.setenv("SUNLANDS_CHANNEL_CODE", value)
        assert Settings.from_env().sunlands_channel_code == value


@pytest.mark.parametrize("channel", (None, "", "offline_test_channel"), ids=("gateway-default", "empty-channel", "configured-channel"))
def test_sunlands_channel_changes_do_not_change_authentication_or_unlock(client, monkeypatch, record_property, channel):
    from dataclasses import replace
    from urllib.parse import parse_qs
    http, app, _, _ = client
    calls = []
    mock_result = {"isSuccess": True, "orderNumber": "OFFLINE_ORDER_001", "payNumber": "OFFLINE_PAY_001",
                   "stuId": 12345, "totalAmount": 10, "orderDetails": [{"itemNo": "193261112000101", "itemPrice": 10}]}
    def upstream(request):
        calls.append(request)
        assert str(request.url) == "https://api-prod.sunlands.com/tradeApi/trade/externalCreateOrder"
        assert request.headers["proxy-authorization"].startswith('hmac username="sunlands_fb_fate",')
        assert "x-consumer-username" not in request.headers
        form = parse_qs(request.content.decode(), keep_blank_values=True)
        if channel in (None, ""):
            assert "channelCode" not in form
        else:
            assert form["channelCode"] == [channel]
        assert "stuId" not in form and form["mobile"] == ["13000000000"] and form["nationCode"] == ["86"]
        assert form["deposit"] == form["depositAmount"] == ["0.00"] and "quicklyPayMethod" not in form
        return httpx.Response(200, json=mock_result)
    payments = sunlands_order_only(app, monkeypatch, upstream)
    monkeypatch.setattr(payments, "settings", replace(payments.settings, sunlands_channel_code=channel))
    report = preview(http)
    path = f"/api/life-reports/{report['id']}"
    result = http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"})
    assert result.status_code == 200 and result.json()["order_number"] == "OFFLINE_ORDER_001"
    assert http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"}).json() == result.json()
    assert len(calls) == 1
    assert app.state.life_reports.card_payments.order_for(report["id"])["provider_order"] is None
    assert http.post(path + "/unlock", headers=HEADERS).status_code == 402
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"
    assert payments.order_for(report["id"])["provider_order"] is None
    record_property("offline_evidence", json.dumps({
        "source": "Scripted success fixture; does not prove any real channel is valid",
        "channel_configuration": channel,
        "request": {"url": str(calls[0].url), "form": parse_qs(calls[0].content.decode(), keep_blank_values=True)},
        "mock_response": mock_result, "local_status": result.status_code, "local_response": result.json(),
        "mock_request_count": len(calls), "report_access": "preview", "paid": False,
    }, ensure_ascii=False))


@pytest.mark.parametrize("channel", ("bad channel", "bad\nchannel", "a" * 65))
def test_sunlands_invalid_channel_configuration_never_creates_an_order(client, monkeypatch, channel):
    from dataclasses import replace
    http, app, _, _ = client
    def upstream(request):
        pytest.fail("Invalid channel configuration must not reach the gateway")
    payments = sunlands_order_only(app, monkeypatch, upstream)
    monkeypatch.setattr(payments, "settings", replace(payments.settings, sunlands_channel_code=channel))
    report = preview(http)
    result = http.post(f"/api/life-reports/{report['id']}/payment", headers=HEADERS,
                       json={"mobile": "13000000000", "nationCode": "86"})
    assert result.status_code == 503 and result.json()["code"] == "life_order_configuration_required"
    assert payments.order_for(report["id"]) is None


def test_sunlands_phone_order_contract_without_payment_or_unlock(client, monkeypatch):
    import base64
    import hashlib
    import hmac
    from urllib.parse import parse_qs
    from backend.app.life_card_payments import LifeCardPayments

    http, app, _, _ = client
    calls = []
    def upstream(request):
        calls.append(request)
        assert str(request.url) == "https://api-prod.sunlands.com/tradeApi/trade/externalCreateOrder"
        form = parse_qs(request.content.decode(), keep_blank_values=True)
        assert form["orderType"] == ["NORMAL"] and form["termType"] == ["mobile"]
        assert "channelCode" not in form
        assert form["itemNo"] == ["193261112000101"]
        assert form["mobile"] == ["13000000000"] and form["nationCode"] == ["86"]
        assert form["provinceId"] == ["4"] and "stuId" not in form
        assert form["totalAmount"] == form["itemPrice"] == ["10.00"]
        assert form["deposit"] == form["depositAmount"] == ["0.00"]
        assert "quicklyPayMethod" not in form
        digest = "SHA-256=" + base64.b64encode(hashlib.sha256(request.content).digest()).decode()
        assert request.headers["digest"] == digest
        signature = base64.b64encode(hmac.new(b"integration-test-secret",
            f'x-date: {request.headers["x-date"]}\ndigest: {digest}'.encode(), hashlib.sha256).digest()).decode()
        assert request.headers["proxy-authorization"].endswith(f'signature="{signature}"')
        return httpx.Response(200, json={"isSuccess": True, "orderNumber": "202611120001",
            "payNumber": "202611120002", "stuId": 12345, "totalAmount": 10,
            "payDirectUrl": "https://checkout.example.test/never-open",
            "orderDetails": [{"itemNo": "193261112000101", "itemPrice": 10, "subSerialNo": "202611120001_1"}]})
    payments = sunlands_order_only(app, monkeypatch, upstream)
    report = preview(http)
    path = f"/api/life-reports/{report['id']}"
    assert report["price"] == {"amount": 1000, "currency": "THB", "display": "฿10", "mode": "sunlands_order_only"}
    assert report["payment_simulation"] is False
    assert http.post(path + "/payment", headers={"X-Report-Key": "z" * 48}).status_code == 404
    order = http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"}).json()
    assert order["reference"] == "000000000001" and order["state"] == "CREATED"
    assert order["order_number"] == "202611120001" and order["order_only"] is True
    assert "payDirectUrl" not in order and "integration-test-secret" not in json.dumps(order)
    # Reopening the application must reuse the persisted platform order.
    restarted = LifeCardPayments(app.state.life_reports.store, payments.settings)
    monkeypatch.setattr(app.state.life_reports, "card_payments", restarted)
    assert http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"}).json() == order
    assert len(calls) == 1
    assert http.post(path + "/payment/simulate", headers=HEADERS, json={"reference": order["reference"]}).status_code == 404
    assert app.state.life_reports.card_payments.order_for(report["id"])["provider_order"] is None
    assert http.post(path + "/unlock", headers=HEADERS).status_code == 402
    assert http.delete(path, headers=HEADERS).status_code == 409
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"
    saved = restarted.order_for(report["id"])
    assert saved["provider_order"] is None
    assert json.loads(saved["sunlands_order"])["subOrderNumbers"] == ["202611120001_1"]
    assert json.loads(saved["sunlands_order"])["stuId"] == "12345"
    assert json.loads(saved["sunlands_order"])["responseSummary"]["isSuccess"] == "True"
    assert saved["sunlands_order_number"] == "202611120001"
    assert saved["sunlands_pay_number"] == "202611120002"
    assert "13000000000" not in json.dumps(order)
    assert "13000000000" not in saved["sunlands_order"]
    assert json.loads(saved["sunlands_order"])["mobileLast4"] == "0000"
    other = http.post("/api/life-reports", headers=HEADERS, json={"profile": PROFILE, "year": 2028}).json()
    async def second_gateway(path, body, content_type):
        form = parse_qs(body.decode())
        assert form["mobile"] == ["812345678"] and form["nationCode"] == ["66"]
        request = httpx.Request("POST", payments.settings.sunlands_base_url + path, content=body)
        return httpx.Response(200, request=request, json={"isSuccess": False,
            "errorMsg": "declined 812345678"})
    monkeypatch.setattr(restarted, "_sunlands_post", second_gateway)
    rejected = http.post(f"/api/life-reports/{other['id']}/payment", headers=HEADERS,
                         json={"mobile": "81 234-5678", "nationCode": "+66"})
    assert rejected.status_code == 409
    second_saved = restarted.order_for(other["id"])
    receipt = json.loads(second_saved["sunlands_order"])
    assert receipt["nationCode"] == "66" and receipt["mobileLast4"] == "5678"
    assert "812345678" not in second_saved["sunlands_order"]
    assert receipt["errorMsg"] == "declined [redacted]"
    assert restarted.order_for(report["id"])["sunlands_order"] == saved["sunlands_order"]


@pytest.mark.parametrize("outcome", ("timeout", "rejected", "wrong_amount", "missing_student"))
def test_sunlands_does_not_repeat_an_uncertain_or_rejected_order(client, monkeypatch, outcome):
    http, app, _, _ = client
    calls = []
    def upstream(request):
        calls.append(request)
        if outcome == "timeout":
            raise httpx.ReadTimeout("synthetic timeout", request=request)
        return httpx.Response(200, json={"isSuccess": outcome != "rejected", "orderNumber": "202611120001",
            "payNumber": "202611120002", "stuId": None if outcome == "missing_student" else 12345,
            "totalAmount": 30 if outcome == "wrong_amount" else 10,
            "orderDetails": [{"itemNo": "193261112000101", "itemPrice": 30 if outcome == "wrong_amount" else 10}]})
    payments = sunlands_order_only(app, monkeypatch, upstream)
    report = preview(http)
    path = f"/api/life-reports/{report['id']}"
    for _ in range(2):
        result = http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"})
        assert result.status_code == 409
        assert result.json()["code"] == ("life_order_rejected" if outcome == "rejected" else "life_order_needs_review")
    assert len(calls) == 1
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"
    state = json.loads(payments.order_for(report["id"])["sunlands_order"])["state"]
    assert state == ("REJECTED" if outcome == "rejected" else "UNKNOWN")
    if outcome == "timeout":
        receipt = json.loads(payments.order_for(report["id"])["sunlands_order"])
        assert receipt["errorType"] == "ReadTimeout" and receipt["failureStage"] == "transport"
        assert receipt["attempts"][0]["errorType"] == "ReadTimeout"
        assert "httpStatus" not in receipt
    if outcome in ("wrong_amount", "missing_student"):
        receipt = json.loads(payments.order_for(report["id"])["sunlands_order"])
        assert receipt["failureStage"] == "validation"
        assert ("totalAmount" if outcome == "wrong_amount" else "stuId") in receipt["validationErrors"]


def test_sunlands_missing_phone_or_province_never_sends_an_order(client, monkeypatch):
    http, app, _, _ = client
    def upstream(request):
        pytest.fail("Incomplete configuration must not reach the gateway")
    payments = sunlands_order_only(app, monkeypatch, upstream)
    report = preview(http)
    path = f"/api/life-reports/{report['id']}"
    for body in (None, {}, {"mobile": "13000000000"}, {"nationCode": "86"},
                 {"mobile": "abc123456", "nationCode": "86"},
                 {"mobile": "13000000000", "nationCode": "000"},
                 {"mobile": "12345678901234", "nationCode": "86"}):
        result = http.post(path + "/payment", headers=HEADERS, json=body)
        assert result.status_code == 422
        assert result.json()["code"] == "life_order_phone_invalid"
        assert payments.order_for(report["id"]) is None
    with monkeypatch.context() as missing:
        missing.setattr(payments.settings, "sunlands_province_id", "")
        assert http.post(path + "/payment", headers=HEADERS,
                         json={"mobile": "13000000000", "nationCode": "86"}).status_code == 503
        assert payments.order_for(report["id"]) is None
    assert http.post(path + "/unlock", headers=HEADERS).status_code == 402


def test_sunlands_access_denied_allows_manual_retry_without_another_local_order(client, monkeypatch):
    http, app, _, _ = client
    calls = []
    def upstream(request):
        calls.append(request)
        if len(calls) == 1:
            return httpx.Response(403, json={"message": "You cannot consume this service"})
        return httpx.Response(200, json={"isSuccess": True, "orderNumber": "202611120003",
            "payNumber": "202611120004", "stuId": 54321, "totalAmount": 10,
            "orderDetails": [{"itemNo": "193261112000101", "itemPrice": 10}]})
    payments = sunlands_order_only(app, monkeypatch, upstream)
    report = preview(http)
    path = f"/api/life-reports/{report['id']}"
    denied = http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"})
    assert denied.status_code == 503 and denied.json()["code"] == "life_order_access_denied"
    original = payments.order_for(report["id"])
    assert json.loads(original["sunlands_order"])["httpStatus"] == 403
    reopened = http.get(path + "/payment", headers=HEADERS)
    assert reopened.status_code == 503 and reopened.json()["code"] == "life_order_access_denied"
    assert len(calls) == 1
    created = http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"}).json()
    assert created["state"] == "CREATED" and created["reference"] == original["reference"]
    assert http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"}).json() == created
    assert len(calls) == 2
    assert json.loads(payments.order_for(report["id"])["sunlands_order"])["stuId"] == "54321"
    receipt = json.loads(payments.order_for(report["id"])["sunlands_order"])
    assert receipt["attemptCount"] == 2
    assert [attempt["state"] for attempt in receipt["attempts"]] == ["ACCESS_DENIED", "CREATED"]
    assert receipt["attempts"][0]["responseSummary"]["message"] == "You cannot consume this service"
    assert app.state.life_reports.card_payments.order_for(report["id"])["provider_order"] is None
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"


@pytest.fixture
def sunlands_settlement(client, monkeypatch, sunlands_phone_response, request):
    from dataclasses import replace
    from urllib.parse import parse_qs
    from backend.app import life_card_payments
    from backend.app.life_card_payments import SUNLANDS_CREATE_ORDER, SUNLANDS_QUERY_ORDER
    http, app, _, _ = client
    calls = []
    number = "OFFLINE_PHONE_ORDER_001"
    price = getattr(request, "param", 10)
    amount = f"{price:.2f}"
    phone_response = json.loads(sunlands_phone_response)
    phone_response["data"]["totalAmount"] = price
    phone_response["data"]["orderDetails"][0]["itemPrice"] = price
    row = {"orderSerialNo": number, "stuId": 12345, "channelCode": "sunlands_fb_fate", "currency": "THB",
           "orderType": "OVERSEAS_NORMAL", "orderStatus": "PAID", "totalAmount": amount,
           "paidAmount": amount, "unpaidAmount": "0.00", "paymentDate": "2026-11-13 12:00:00",
           "orderDetails": [{"subOrderSerialNo": number + "_1", "subOrderStatus": "PAID",
                             "itemNo": "193261112000101", "totalAmount": amount,
                             "payInfo": {"currency": "THB", "paidAmount": amount, "totalAmount": amount}}]}
    state = {"response": {"retCode": "0", "data": [row]}, "status": 200, "error": None}
    def upstream(request):
        calls.append(request.url.path)
        if request.url.path == SUNLANDS_CREATE_ORDER:
            form = parse_qs(request.content.decode())
            assert form["merchantNotifyUrl"] == ["/api/life-reports/payment/sunlands/notify"]
            assert form["itemPrice"] == form["totalAmount"] == [amount]
            return httpx.Response(200, json=phone_response)
        assert request.url.path == SUNLANDS_QUERY_ORDER
        assert parse_qs(request.content.decode()) == {"orderSerialNos": [json.dumps([number])], "orderContent": ['["PAY","ITEM"]']}
        assert request.headers["proxy-authorization"].startswith('hmac username="sunlands_fb_fate",')
        if state["error"] == "timeout":
            raise httpx.ReadTimeout("offline timeout", request=request)
        return httpx.Response(state["status"], json=state["response"])
    payments = sunlands_order_only(app, monkeypatch, upstream)
    monkeypatch.setattr(payments, "settings", replace(payments.settings,
        sunlands_merchant_notify_uri="/api/life-reports/payment/sunlands/notify"))
    report = preview(http)
    path = f"/api/life-reports/{report['id']}"
    with monkeypatch.context() as previous_pricing:
        if price != 10:
            previous_pricing.setattr(life_card_payments, "SUNLANDS_AMOUNT", price * 100)
        created = http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"})
    assert created.status_code == 200 and created.json()["amount"] == price * 100
    notice = {"callBackType": "pay", "subOrderStatusCode": "PAID", "subOrderNumber": number + "_1",
              "orderNumber": number, "userId": "12345", "itemNo": "193261112000101", "amount": amount,
              "orderType": "OVERSEAS_NORMAL", "currency": "THB", "eventTime": "2026-11-13 12:00:00"}
    return http, app, payments, report, path, state, calls, notice


def test_sunlands_denial_with_a_platform_number_never_allows_manual_reordering(client, monkeypatch):
    http, app, _, _ = client
    calls = []
    def upstream(request):
        calls.append(request.url.path)
        return httpx.Response(403, json={"message": "You cannot consume this service", "orderNumber": "EXISTING_ORDER"})
    payments = sunlands_order_only(app, monkeypatch, upstream)
    report = preview(http)
    path = f"/api/life-reports/{report['id']}/payment"
    for _ in range(2):
        response = http.post(path, headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"})
        assert response.status_code == 409 and response.json()["code"] == "life_order_needs_review"
    assert http.get(path, headers=HEADERS).json()["code"] == "life_order_needs_review"
    assert len(calls) == 1
    assert payments.order_for(report["id"])["sunlands_order_number"] == "EXISTING_ORDER"


@pytest.mark.parametrize("sunlands_settlement", [10, 30], indirect=True, ids=["new-price", "previous-price"])
def test_sunlands_settlement_checks_pending_then_unlocks_atomically_and_survives_restart(sunlands_settlement):
    from backend.app.life_card_payments import LifeCardPayments, SUNLANDS_QUERY_ORDER
    http, app, payments, report, path, state, calls, notice = sunlands_settlement
    amount = notice["amount"].removesuffix(".00")
    paid_result = deepcopy(state["response"])
    state["response"]["data"][0].update(orderStatus="UNPAID", paidAmount="0.00", unpaidAmount=notice["amount"])
    assert http.post(path + "/payment/check", headers={"X-Report-Key": "z" * 48}).status_code == 404
    assert http.post(path + "/payment/check", headers=HEADERS).json() == {"paid": False}
    assert http.post(path + "/unlock", headers=HEADERS).status_code == 402
    pending = http.get(path, headers=HEADERS).json()
    existing = http.get(path + "/payment", headers=HEADERS).json()
    assert pending["access"] == "preview"
    assert pending["price"]["display"] == f"฿{amount}"
    assert pending["price"]["amount"] == existing["amount"] == int(amount) * 100
    state["response"] = {"flag": "1", "data": paid_result}
    assert http.post(path + "/payment/check", headers=HEADERS).json() == {"paid": True}
    saved = payments.order_for(report["id"])
    receipt = json.loads(saved["sunlands_order"])
    assert saved["provider_order"] == "https://api-prod.sunlands.com/OFFLINE_PHONE_ORDER_001"
    assert receipt["paymentStatus"] == "PAID" and receipt["stuId"] == "12345"
    assert [check["status"] for check in receipt["paymentChecks"]] == ["PENDING", "PAID"]
    assert len(receipt["attempts"]) == 1
    assert http.get(path, headers=HEADERS).json()["access"] == "full"
    app.state.life_reports.card_payments = LifeCardPayments(payments.store, payments.settings)
    assert http.post(path + "/payment/check", headers=HEADERS).json() == {"paid": True}
    assert calls.count(SUNLANDS_QUERY_ORDER) == 2
    finish(http, app)
    assert http.get(path, headers=HEADERS).json()["full_state"] == "ready"


@pytest.mark.parametrize("mismatch", ["order", "student", "channel", "currency", "amount", "item", "suborder", "pay_amount", "nan", "signaling_nan", "provider_conflict"])
def test_sunlands_settlement_rejects_mismatched_payment(sunlands_settlement, mismatch):
    http, _, payments, report, path, state, _, _ = sunlands_settlement
    row = state["response"]["data"][0]
    line = row["orderDetails"][0]
    if mismatch == "order": row["orderSerialNo"] = "ANOTHER_ORDER"
    elif mismatch == "student": row["stuId"] = 54321
    elif mismatch == "channel": row["channelCode"] = "another_app"
    elif mismatch == "currency": row["currency"] = "CNY"
    elif mismatch == "amount": row.update(paidAmount="9.00", unpaidAmount="1.00")
    elif mismatch == "item": line["itemNo"] = "ANOTHER_ITEM"
    elif mismatch == "suborder": line["subOrderSerialNo"] = "ANOTHER_SUBORDER"
    elif mismatch == "pay_amount": line["payInfo"]["paidAmount"] = "1.00"
    elif mismatch == "nan": row["paidAmount"] = "NaN"
    elif mismatch == "signaling_nan": row["paidAmount"] = "sNaN"
    elif mismatch == "provider_conflict":
        with payments.store.connect() as db:
            db.execute("UPDATE life_card_payments SET provider_order='OTHER_PROVIDER_ORDER' WHERE report_id=%s", (report["id"],))
    checked = http.post(path + "/payment/check", headers=HEADERS)
    assert checked.status_code == 409 and checked.json()["code"] == "life_payment_verification_failed"
    saved = payments.order_for(report["id"])
    assert saved["provider_order"] == ("OTHER_PROVIDER_ORDER" if mismatch == "provider_conflict" else None)
    assert json.loads(saved["sunlands_order"])["paymentStatus"] == "CHECK_FAILED"
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"


@pytest.mark.parametrize("outcome", ["denied", "timeout", "malformed", "business_failure"])
def test_sunlands_settlement_errors_are_saved_without_claiming_unpaid_or_reordering(sunlands_settlement, outcome):
    http, _, payments, report, path, state, calls, _ = sunlands_settlement
    if outcome == "denied": state["status"] = 403
    elif outcome == "timeout": state["error"] = "timeout"
    elif outcome == "malformed": state["response"] = ["invalid"]
    else: state["response"] = {"retCode": "1", "data": []}
    checked = http.post(path + "/payment/check", headers=HEADERS)
    assert checked.status_code == 503 and "paid" not in checked.json()
    if outcome == "denied": assert checked.json()["code"] == "life_payment_check_access_denied"
    saved = payments.order_for(report["id"])
    assert saved["provider_order"] is None
    assert json.loads(saved["sunlands_order"])["paymentStatus"] == "CHECK_FAILED"
    assert len(calls) == 2 and http.get(path, headers=HEADERS).json()["access"] == "preview"


def test_sunlands_callback_cannot_unlock_without_server_confirmation_and_is_idempotent(sunlands_settlement):
    http, app, payments, report, path, state, calls, notice = sunlands_settlement
    endpoint = "/api/life-reports/payment/sunlands/notify"
    assert http.post(endpoint, data={**notice, "amount": "1.00"}).json()["code"] == 0
    assert http.post(endpoint, data={**notice, "currency": "CNY"}).json()["code"] == 0
    assert len(calls) == 1
    paid = deepcopy(state["response"])
    state["response"]["data"][0].update(orderStatus="UNPAID", paidAmount="0.00", unpaidAmount=notice["amount"])
    assert http.post(endpoint, data=notice).json()["code"] == 0
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"
    state["response"] = paid
    assert http.post(endpoint, data={**notice, "subOrderNumber": "ANOTHER_SUBORDER"}).json()["code"] == 0
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"
    assert http.post(endpoint, data=notice).json() == {"code": 1, "msg": "success"}
    before = len(calls)
    assert http.post(endpoint, data=notice).json() == {"code": 1, "msg": "success"}
    assert len(calls) == before
    assert len(json.loads(payments.order_for(report["id"])["sunlands_order"])["attempts"]) == 1
    finish(http, app)
    assert http.get(path, headers=HEADERS).json()["full_state"] == "ready"
    assert http.post(endpoint, content="orderNumber=a&orderNumber=b", headers={"Content-Type": "application/x-www-form-urlencoded"}).status_code == 400


def test_twelve_verified_reports_drain_and_resume_saved_chapters_after_restart(
    postgres_url, monkeypatch, sunlands_phone_response, record_property,
):
    from collections import Counter
    from urllib.parse import parse_qs
    from backend.app import thai
    from backend.app.bazi_reports import report_usage_context
    from backend.app.life_card_payments import LifeCardPayments, SUNLANDS_CREATE_ORDER, SUNLANDS_QUERY_ORDER

    settings = Settings(database_url=postgres_url, app_env="development", sunlands_order_only=True,
                        sunlands_app_secret="offline-test-secret", sunlands_province_id="4",
                        life_generation_concurrency=32, bazi_reports_per_minute=100, bazi_reports_per_day=100,
                        providers={"qwen": ProviderConfig("offline", "https://model.example/v1", "test")})
    network = "isolated-batch-network"
    chart = thai.natal(PROFILE)
    monkeypatch.setattr(thai, "natal", lambda profile: deepcopy(chart))
    upstream_calls = Counter()

    async def gateway(self, path, body, content_type):
        upstream_calls[path] += 1
        if path == SUNLANDS_CREATE_ORDER:
            payload = json.loads(sunlands_phone_response)
            record = payload["data"]
            number = f"OFFLINE_BATCH_{upstream_calls[path]:02d}"
            record["payDirectUrl"] = record["payDirectUrl"].replace(record["orderNumber"], number)
            record["orderNumber"] = number
            record["orderDetails"][0]["subSerialNo"] = number + "_1"
        else:
            assert path == SUNLANDS_QUERY_ORDER
            number, = json.loads(parse_qs(body.decode())["orderSerialNos"][0])
            payload = {"retCode": "0", "data": [{
                "orderSerialNo": number, "stuId": "12345", "channelCode": settings.sunlands_app_key,
                "currency": "THB", "orderType": "OVERSEAS_NORMAL", "orderStatus": "PAID",
                "totalAmount": "10.00", "paidAmount": "10.00", "unpaidAmount": "0.00",
                "orderDetails": [{"subOrderSerialNo": number + "_1", "subOrderStatus": "PAID",
                                  "itemNo": settings.sunlands_item_no, "totalAmount": "10.00",
                                  "payInfo": {"currency": "THB", "totalAmount": "10.00", "paidAmount": "10.00"}}],
            }]}
        return httpx.Response(200, json=payload, request=httpx.Request("POST", "https://payment.example" + path))

    monkeypatch.setattr(LifeCardPayments, "_sunlands_post", gateway)

    async def exercise():
        hold = True
        release_saved, blocked, saturated = asyncio.Event(), asyncio.Event(), asyncio.Event()
        saving = None
        active = maximum = 0
        calls, active_by_report = Counter(), Counter()

        async def write(self, bundle, **kwargs):
            nonlocal active, maximum
            story = thai_story_for(bundle) if bundle["language"] == "th" else story_for(bundle)
            if bundle["stage"] == "preview":
                return self.validate(json.dumps(story, ensure_ascii=False), bundle)
            report_id, _ = report_usage_context.get()
            key = (report_id, bundle["reading"])
            calls[key] += 1
            active += 1
            active_by_report[report_id] += 1
            maximum = max(maximum, active)
            try:
                assert active_by_report[report_id] <= 3 and active <= 32
                if hold:
                    if active == 30:
                        saturated.set()
                    await (release_saved if key == (saving, "work") else blocked).wait()
                else:
                    await asyncio.sleep(0.02)
                return self.validate(json.dumps(story, ensure_ascii=False), bundle)
            finally:
                active -= 1
                active_by_report[report_id] -= 1

        monkeypatch.setattr(LifeWriter, "write", write)
        app = create_app(settings)
        service = app.state.life_reports
        store = app.state.store

        def snapshots():
            with store.connect() as db:
                return db.execute("SELECT id,owner,input,unlocked,full_state,chapters,plan "
                                  "FROM life_reports ORDER BY created,id").fetchall()

        async def until(predicate):
            async with asyncio.timeout(40):
                while not predicate(snapshots()):
                    await asyncio.sleep(0.05)

        # Arrange 12 valid previews and test cashiers, with all provider calls replaced.
        async with app.router.lifespan_context(app):
            previews = await asyncio.gather(*(
                service.create(LifeInput(profile={**PROFILE, "language": "zh" if i < 6 else "th"}, year=2027),
                               f"batch-owner-{i}", network)
                for i in range(12)
            ))
            assert all(preview["preview_state"] == "ready" for preview in previews)
            await asyncio.gather(*(service.card_payments.create_sunlands(
                preview["id"], network, "800000000", "66") for preview in previews))

        # Confirm with the worker offline, so no notification or browser can start the tasks.
        started = time.perf_counter()
        orders = [service.card_payments.order_for(preview["id"]) for preview in previews]
        assert all(await asyncio.gather(*(service.card_payments.confirm_sunlands(order) for order in orders)))
        settle_s = time.perf_counter() - started
        paid = snapshots()
        assert len(paid) == 12 and all(row["unlocked"] == 1 and row["full_state"] == "queued" for row in paid)
        saving = paid[0]["id"]
        assert await service.card_payments.confirm_sunlands(service.card_payments.order_for(saving))
        assert upstream_calls[SUNLANDS_QUERY_ORDER] == 12

        worker = create_app(settings)
        async with worker.router.lifespan_context(worker):
            await asyncio.wait_for(saturated.wait(), 25)
            in_progress = Counter(row["full_state"] for row in snapshots())
            assert in_progress == {"generating": 10, "queued": 2}
            release_saved.set()
            await until(lambda rows: "work" in json.loads(rows[0]["chapters"]))
            saved_work = json.loads(snapshots()[0]["chapters"])["work"]

        # Leave one in-progress lease for the new worker to reclaim after it expires.
        assert snapshots()[0]["full_state"] == "pending"
        with store.connect() as db:
            db.execute("UPDATE life_reports SET full_state='generating',lease='interrupted-worker' WHERE id=%s", (saving,))
        hold = False
        worker = create_app(settings)
        async with worker.router.lifespan_context(worker):
            await until(lambda rows: all(row["full_state"] == "ready" for row in rows))
        finished_s = time.perf_counter() - started
        final = snapshots()
        assert json.loads(final[0]["chapters"])["work"] == saved_work and calls[(saving, "work")] == 1
        assert all(len(json.loads(row["chapters"])) == 5 and row["plan"] for row in final)
        languages = Counter(json.loads(row["input"])["profile"]["language"] for row in final)
        assert languages == {"zh": 6, "th": 6}
        with store.connect() as db:
            assert db.execute("SELECT COUNT(*) AS total FROM bazi_report_usage WHERE scope=%s",
                              (network,)).fetchone()["total"] == 24
            assert db.execute("SELECT COUNT(DISTINCT provider_order) AS total FROM life_card_payments").fetchone()["total"] == 12
        return {"accepted": 12, "completed": len(final), "languages": dict(languages),
                "initial_generating": in_progress["generating"], "initial_queued": in_progress["queued"],
                "peak_model_calls": maximum, "settlement_s": round(settle_s, 3),
                "completion_s_including_restart": round(finished_s, 3), "saved_chapter_reused": True,
                "payment": "offline gateway fixture", "writer": "validated synthetic output"}

    observed = asyncio.run(exercise())
    record_property("full_queue_result", json.dumps(observed))
    print(json.dumps(observed))


@pytest.mark.parametrize("outcome", ("structured_error", "html_success", "html_error", "business_error", "channel_error"))
def test_sunlands_failure_receipts_are_durable_and_redacted(client, monkeypatch, record_property, outcome):
    http, app, _, _ = client
    calls = []
    def upstream(request):
        calls.append(request)
        headers = {"x-request-id": "mock-request-id"}
        if outcome.startswith("html"):
            return httpx.Response(200 if outcome == "html_success" else 502,
                                  text="<html>13000000000 integration-test-secret</html>",
                                  headers={**headers, "content-type": "text/html"})
        if outcome == "structured_error":
            return httpx.Response(403, json={"message": {"code": "denied", "mobile": "13000000000"}}, headers=headers)
        if outcome == "channel_error":
            return httpx.Response(200, json={"flag": "0", "message": "channelCode不正确: sunlands_fb_fate"}, headers=headers)
        return httpx.Response(200, json={"isSuccess": False, "errorMsg":
            "13000000000 integration-test-secret " + request.headers["proxy-authorization"]}, headers=headers)
    payments = sunlands_order_only(app, monkeypatch, upstream)
    report = preview(http)
    path = f"/api/life-reports/{report['id']}"
    for _ in range(2):
        response = http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"})
        assert response.status_code == 409
    assert len(calls) == 1
    saved = payments.order_for(report["id"])
    receipt = json.loads(saved["sunlands_order"])
    if outcome == "channel_error":
        from urllib.parse import parse_qs
        record_property("offline_evidence", json.dumps({
            "source": "MockTransport replay; no external request",
            "request": {"url": str(calls[0].url), "form": parse_qs(calls[0].content.decode())},
            "mock_response": {"flag": "0", "message": "channelCode不正确: sunlands_fb_fate"},
            "local_response": response.json(), "local_status": response.status_code,
            "saved_response": receipt["responseSummary"], "mock_request_count": len(calls),
        }, ensure_ascii=False))
    assert receipt["state"] == ("REJECTED" if outcome == "business_error" else "UNKNOWN")
    assert receipt["failureStage"] == {"structured_error": "http", "html_success": "parse",
                                       "html_error": "http", "business_error": "business", "channel_error": "business"}[outcome]
    assert receipt["httpStatus"] == {"structured_error": 403, "html_success": 200,
                                     "html_error": 502, "business_error": 200, "channel_error": 200}[outcome]
    assert receipt["gatewayRequestId"] == "mock-request-id"
    assert receipt["requestDate"] == calls[0].headers["x-date"]
    assert receipt["responseBytes"] > 0 and len(receipt["responseHash"]) == 64 and receipt["elapsedMs"] >= 0
    assert len(receipt["attempts"]) == 1 and receipt["attempts"][0]["httpStatus"] == receipt["httpStatus"]
    assert receipt["attempts"][0]["requestSummary"]["mobile"] == "***0000"
    assert receipt["attempts"][0]["requestSummary"]["totalAmount"] == "10.00"
    if outcome.startswith("html"):
        assert receipt["contentType"] == "text/html" and receipt["parseErrorType"] == "JSONDecodeError"
    if outcome == "structured_error":
        assert receipt["responseSummary"]["message"] == "<dict>"
    if outcome == "channel_error":
        assert receipt["responseSummary"] == {"flag": "0", "message": "channelCode不正确: sunlands_fb_fate"}
        assert "validationErrors" not in receipt and "stuId" not in receipt
        assert receipt["endpoint"] == "/tradeApi/trade/externalCreateOrder"
        assert response.json()["code"] == "life_order_channel_invalid"
        # Old receipts omitted flag; reopening must still explain the channel failure without another request.
        from backend.app.life_card_payments import LifeCardPayments
        legacy = deepcopy(receipt)
        legacy["responseSummary"].pop("flag")
        legacy["failureStage"] = "validation"
        with payments.store.connect() as db:
            db.execute("UPDATE life_card_payments SET sunlands_order=%s WHERE reference=%s",
                       (json.dumps(legacy), saved["reference"]))
        restarted = LifeCardPayments(payments.store, payments.settings)
        monkeypatch.setattr(app.state.life_reports, "card_payments", restarted)
        reopened = http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"})
        assert reopened.status_code == 409 and reopened.json()["code"] == "life_order_channel_invalid"
        assert len(calls) == 1
        assert json.loads(restarted.order_for(report["id"])["sunlands_order"]) == legacy
    assert "13000000000" not in saved["sunlands_order"]
    assert "integration-test-secret" not in saved["sunlands_order"]
    assert calls[0].headers["proxy-authorization"] not in saved["sunlands_order"]
    assert "gatewayRequestId" not in response.text
    assert saved["provider_order"] is None
    assert app.state.life_reports.card_payments.order_for(report["id"])["provider_order"] is None
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"


@pytest.mark.parametrize("duplicate_field", ("orderNumber", "payNumber"))
def test_sunlands_platform_numbers_cannot_bind_two_reports(client, monkeypatch, duplicate_field):
    from psycopg.errors import UniqueViolation
    from backend.app.life_card_payments import LifeCardPayments

    http, app, _, _ = client
    calls = []
    def upstream(request):
        calls.append(request)
        result = {"isSuccess": True, "orderNumber": f"ORDER_{len(calls)}", "payNumber": f"PAY_{len(calls)}",
                  "stuId": 12345, "totalAmount": 10,
                  "orderDetails": [{"itemNo": "193261112000101", "itemPrice": 10}]}
        result[duplicate_field] = "SHARED_PLATFORM_NUMBER"
        return httpx.Response(200, json=result)
    payments = sunlands_order_only(app, monkeypatch, upstream)
    reports = [preview(http), http.post("/api/life-reports", headers=HEADERS,
                json={"profile": PROFILE, "year": 2028}).json()]
    first = http.post(f"/api/life-reports/{reports[0]['id']}/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"})
    assert first.status_code == 200
    path = f"/api/life-reports/{reports[1]['id']}"
    response = http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"})
    assert response.status_code == 409 and response.json()["code"] == "life_order_needs_review"
    saved = payments.order_for(reports[1]["id"])
    receipt = json.loads(saved["sunlands_order"])
    assert receipt["state"] == "UNKNOWN" and receipt["failureStage"] == "association"
    assert receipt[duplicate_field] == "SHARED_PLATFORM_NUMBER"
    assert receipt["associationConflict"]["references"] == [first.json()["reference"]]
    assert receipt["attempts"][0]["failureStage"] == "association"
    assert saved["sunlands_order_number"] is None and saved["sunlands_pay_number"] is None
    # The database, not only the API check, rejects a second binding.
    column = "sunlands_order_number" if duplicate_field == "orderNumber" else "sunlands_pay_number"
    with payments.store.connect() as db, pytest.raises(UniqueViolation):
        db.execute(f"UPDATE life_card_payments SET sunlands_gateway=%s,{column}=%s WHERE reference=%s",
                   (payments.settings.sunlands_base_url, "SHARED_PLATFORM_NUMBER", saved["reference"]))
    restarted = LifeCardPayments(payments.store, payments.settings)
    monkeypatch.setattr(app.state.life_reports, "card_payments", restarted)
    assert http.post(path + "/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"}).status_code == 409
    assert len(calls) == 2 and http.get(path, headers=HEADERS).json()["access"] == "preview"
    assert restarted.order_for(reports[1]["id"])["sunlands_order"] == saved["sunlands_order"]


def test_sunlands_concurrent_responses_reserve_platform_order_once(client, monkeypatch):
    http, app, _, _ = client
    ready, release = asyncio.Event(), asyncio.Event()
    calls = []
    async def upstream(request):
        calls.append(request)
        if len(calls) == 2:
            ready.set()
        await release.wait()
        return httpx.Response(200, json={"isSuccess": True, "orderNumber": "SHARED_ORDER", "payNumber": "SHARED_PAY",
            "stuId": 12345, "totalAmount": 10, "orderDetails": [{"itemNo": "193261112000101", "itemPrice": 10}]})
    payments = sunlands_order_only(app, monkeypatch, upstream)
    reports = [preview(http), http.post("/api/life-reports", headers=HEADERS,
                json={"profile": PROFILE, "year": 2028}).json()]
    async def run():
        tasks = [asyncio.create_task(payments.create_sunlands(report["id"], "test-network", "13000000000", "86")) for report in reports]
        await asyncio.wait_for(ready.wait(), timeout=3)
        release.set()
        return await asyncio.gather(*tasks, return_exceptions=True)
    results = http.portal.call(run)
    assert sum(isinstance(result, dict) for result in results) == 1
    assert sum(getattr(result, "status_code", None) == 409 for result in results) == 1
    rows = [payments.order_for(report["id"]) for report in reports]
    assert sum(row["sunlands_order_number"] == "SHARED_ORDER" for row in rows) == 1
    assert all(row["provider_order"] is None for row in rows)
    assert len(calls) == 2


def test_sunlands_cancelled_request_is_recorded_without_retry(client, monkeypatch):
    http, app, _, _ = client
    entered = asyncio.Event()
    calls = []
    async def upstream(request):
        calls.append(request)
        entered.set()
        await asyncio.Future()
    payments = sunlands_order_only(app, monkeypatch, upstream)
    report = preview(http)
    async def run():
        task = asyncio.create_task(payments.create_sunlands(report["id"], "test-network", "13000000000", "86"))
        await asyncio.wait_for(entered.wait(), timeout=3)
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task
    http.portal.call(run)
    receipt = json.loads(payments.order_for(report["id"])["sunlands_order"])
    assert receipt["state"] == "UNKNOWN" and receipt["errorType"] == "CancelledError"
    assert receipt["attempts"][0]["errorType"] == "CancelledError"
    assert http.post(f"/api/life-reports/{report['id']}/payment", headers=HEADERS, json={"mobile": "13000000000", "nationCode": "86"}).status_code == 409
    assert len(calls) == 1


def test_postgres_import_preserves_sunlands_receipt_and_unlock(tmp_path, postgres_url):
    from contextlib import closing
    import os
    from pathlib import Path
    import sqlite3
    import subprocess
    import sys

    from backend.app.life_card_payments import LifeCardPayments
    from backend.app.storage import Storage

    store = Storage(postgres_url)
    gateway = "https://api-prod.sunlands.com"
    receipt = json.dumps({"state": "CREATED", "gateway": gateway, "orderNumber": "LEGACY_ORDER",
                          "payNumber": "LEGACY_PAY", "paymentStatus": "PAID", "paidAt": 123.5})
    source_file = tmp_path / "business.db"
    with store.connect() as db:
        fields = db.execute("SELECT table_name,column_name FROM information_schema.columns "
                            "WHERE table_schema=current_schema() AND table_name<>'alembic_version' "
                            "ORDER BY table_name,ordinal_position").fetchall()
    tables = {}
    for field in fields:
        tables.setdefault(field["table_name"], []).append(field["column_name"])
    with closing(sqlite3.connect(source_file)) as source, source:
        for table in ["life_reports", *(name for name in tables if name != "life_reports")]:
            source.execute(f"CREATE TABLE {table} ({','.join(tables[table])})")
        source.execute("INSERT INTO life_simulated_payment_sequence VALUES (17)")
        source.execute(
            "INSERT INTO life_reports(id,owner,fingerprint,input,chart,created,preview_state,chapters,"
            "unlocked,full_state,lease,lease_until,generation_progress) "
            "VALUES ('report-a','life:owner','key','{}','{}',100,'ready','{}',1,'ready','',0,'{}')"
        )
        source.execute("INSERT INTO life_card_payments VALUES (?,?,?,?,?,?,?,?,?,?)",
                       ("000000000017", "report-a", "network", "sunlands:sunlands_fb_fate", 3000,
                        gateway + "/LEGACY_ORDER", receipt, gateway, "LEGACY_ORDER", "LEGACY_PAY"))
    script = Path(__file__).resolve().parents[2] / "scripts/migrate-sqlite-to-postgres.py"
    job = subprocess.run([sys.executable, str(script), "--source", str(source_file)],
                         env={**os.environ, "DATABASE_URL": postgres_url}, capture_output=True, text=True)
    assert job.returncode == 0, job.stderr
    assert json.loads(job.stdout)["unlocked_life_reports"] == 1
    payments = LifeCardPayments(Storage(postgres_url), Settings())
    old = payments.order_for("report-a")
    assert (old["reference"], old["amount"], old["sunlands_order"], old["provider_order"]) == (
        "000000000017", 3000, receipt, gateway + "/LEGACY_ORDER")
    with store.connect() as db:
        assert db.execute("SELECT unlocked FROM life_reports WHERE id='report-a'").fetchone()["unlocked"] == 1
        assert db.execute("SELECT number FROM life_simulated_payment_sequence").fetchone()["number"] == 17


@pytest.mark.parametrize("report_kind", ("life", "fortune"))
def test_payso_demo_only_unlocks_the_order_verified_by_inquiry(client, monkeypatch, report_kind):
    http, app, _, _ = client
    monkeypatch.setattr(app.state.life_reports, "development", True)
    payments = app.state.life_reports.card_payments
    monkeypatch.setattr(payments, "enabled", True)
    monkeypatch.setattr(payments, "merchant", "12345678")
    response = http.post("/api/life-reports", json={"profile": PROFILE, "year": 2027, "report_kind": report_kind}, headers=HEADERS)
    assert response.status_code == 200, response.text
    report = response.json()
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
    assert paid["access"] == "full" and paid["full_state"] == "ready"
    assert len(paid["chapters"]) == (7 if report_kind == "fortune" else 5)


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
    assert free["title"] == "人生报告"
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
    story["summary"]["text"] = "摘要" * 130
    with pytest.raises(InvalidBaziReport) as error:
        validate_life_story(json.dumps(story, ensure_ascii=False), bundle)
    assert "actions.0.steps.0" in error.value.feedback
    assert "actions.1.steps.2" in error.value.feedback
    assert "私人短句" not in error.value.feedback
    assert '"field": "stage"' in error.value.feedback and "REMOVE this unexpected key entirely" in error.value.feedback
    assert '"field": "summary.text"' in error.value.feedback
    assert "at most 240 characters" in error.value.feedback
    assert "at most 120 Unicode characters" in error.value.feedback


def test_thai_chapter_prompt_keeps_the_summary_separate_from_long_paragraphs(client):
    http, app, calls, _ = client
    result = preview(http)
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    bundle = {**next(row for row in calls if row["stage"] == "chapter"), "language": "th"}
    prompt = app.state.life_reports.parts_writer.prompt(bundle)
    assert "summary.text targets 40-80 Thai Unicode characters, with a hard maximum of 240 characters" in prompt
    assert "six point text fields target 160-240 Unicode characters each" in prompt
    assert "ALL SIX point text fields" in prompt


@pytest.mark.parametrize("language", ("zh", "th"))
def test_paid_chapter_keeps_its_field_repair_after_a_timeout(client, monkeypatch, language):
    http, app, _, _ = client
    writer = app.state.life_reports.parts_writer
    writer.config.model = "qwen3.7-plus"
    writer.generation_timeout = 2
    real_client = httpx.AsyncClient
    calls, repairs = [], []
    expected = {}
    fixture = thai_story_for if language == "th" else story_for
    reading = "annual" if language == "zh" else "pattern"
    path_parts = ["watchpoints", 0, "signals", 0] if language == "zh" else ["actions", 0, "text"]
    field = ".".join(map(str, path_parts))

    def parent(story):
        for key in path_parts[:-1]:
            story = story[key]
        return story

    async def write_preview(self, bundle, **kwargs):
        return self.validate(json.dumps(fixture(bundle), ensure_ascii=False), bundle)

    async def handler(request):
        payload = json.loads(request.content)
        bundle = json.loads(payload["messages"][1]["content"])
        calls.append(bundle["reading"])
        story = fixture(bundle)
        if bundle["reading"] == reading:
            key = path_parts[-1]
            original = parent(story)[key]
            bad_text = "只看余额" if language == "zh" else original + " Google Drive"
            correction = bundle.get("correction")
            if correction:
                repairs.append(correction)
                assert correction["fields"] == {field: path_parts}
                assert parent(json.loads(correction["draft"]))[key] is None
                issue = {"field": field, "rule": "language"}
                if language == "zh":
                    issue.update(rule="string_too_short", min_length=12, actual_length=4)
                    requirements = correction["field_requirements"][field]
                    assert requirements["minLength"] == 12 and "25至55个汉字" in requirements["description"]
                assert correction["field_errors"] == [issue]
                schema = payload["response_format"]["json_schema"]["schema"]
                assert schema["required"] == [field] and schema["properties"][field]["type"] == "string"
                if len(repairs) == 1:
                    if language == "zh":
                        await asyncio.Event().wait()
                    raise httpx.ReadTimeout("synthetic read timeout", request=request)
                story = {field: bad_text if len(repairs) <= 3 else original}
            else:
                expected.update(writer.validate(json.dumps(story, ensure_ascii=False), bundle))
                parent(story)[key] = bad_text
        return httpx.Response(200, json={"choices": [{"finish_reason": "stop",
            "message": {"content": json.dumps(story, ensure_ascii=False)}}]})

    monkeypatch.setattr(LifeWriter, "write", write_preview)
    monkeypatch.setattr(writer, "write", BaziReports.write.__get__(writer))
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    report = http.post("/api/life-reports", json={"profile": {**PROFILE, "language": language}, "year": 2027,
                       "report_kind": "fortune"}, headers=HEADERS).json()
    assert report["preview_state"] == "ready"
    path = f"/api/life-reports/{report['id']}"
    http.post(path + "/unlock", json={}, headers=HEADERS).raise_for_status()
    finish(http, app)
    full = http.get(path, headers=HEADERS).json()
    assert full["full_state"] == "ready" and len(full["chapters"]) == 7 and full["plan"]
    assert len(repairs) == 4 and repairs[0] == repairs[1]
    assert calls.count(reading) == 5 and len(calls) == 12
    with app.state.store.connect() as db:
        row = db.execute("SELECT chapters FROM life_reports WHERE id=%s", (report["id"],)).fetchone()
        errors = {entry["error_code"] for entry in db.execute(
            "SELECT error_code FROM report_model_usage WHERE report_id=%s AND reading=%s", (report["id"], reading))}
    assert json.loads(row["chapters"])[reading]["story"] == expected
    assert ("CancelledError" if language == "zh" else "ReadTimeout") in errors


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
        row = db.execute("SELECT chapters,plan FROM life_reports WHERE id=%s", (report["id"],)).fetchone()
        records, plan = json.loads(row["chapters"]), json.loads(row["plan"])
        records["overview"] = deepcopy(records["work"])
        plan["phases"][0]["action_ids"][0] = "overview:0"
        db.execute("UPDATE life_reports SET chapters=%s,plan=%s WHERE id=%s", (json.dumps(records), json.dumps(plan), report["id"]))
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


@pytest.mark.parametrize("language", ["zh", "th"])
def test_h5_app_login_syncs_existing_and_future_reports(client, monkeypatch, language):
    http, app, _, _ = client
    service = app.state.life_reports
    monkeypatch.setattr(service, "development", True)

    async def write(self, bundle, **kwargs):
        story = thai_story_for(bundle) if bundle["language"] == "th" else story_for(bundle)
        return self.validate(json.dumps(story, ensure_ascii=False), bundle)

    monkeypatch.setattr(LifeWriter, "write", write)
    source_headers = {**HEADERS, "Accept-Language": language}
    other_headers = {**source_headers, "X-Report-Key": "other-browser-key-" + "z" * 32}

    def create(headers, year):
        response = http.post("/api/life-reports", headers=headers,
                             json={"profile": {**PROFILE, "language": language}, "year": year})
        assert response.status_code == 200 and response.json()["preview_state"] == "ready"
        return response.json()

    first, foreign = create(source_headers, 2027), create(other_headers, 2027)
    source_path = f"/api/life-reports/{first['id']}"
    code_path = source_path + "/app-login-code"
    listing = "/api/app/h5-reports"
    assert http.get(listing).status_code == 401
    assert http.post(code_path, headers=other_headers).status_code == 404
    with app.state.store.connect() as db:
        # Give the remaining historical entries the same timestamp to exercise the tie breaker.
        db.execute("""INSERT INTO life_reports(id, owner, fingerprint, input, chart, created, preview, preview_state)
                      SELECT 'history-' || n, owner, 'fixture-' || n, input, chart, created, preview, preview_state
                      FROM life_reports, generate_series(1,30) AS n WHERE id=%s""", (first["id"],))

    def issue():
        response = http.post(code_path, headers=source_headers)
        assert response.status_code == 200 and response.headers["Cache-Control"] == "no-store"
        assert response.json()["expires_in"] == 600
        code = response.json()["code"]
        assert re.fullmatch(r"(?=.*[A-Z])(?=.*[2-9])[A-Z2-9]{6}", code)
        return code

    def redeem(code):
        return http.post("/api/auth/h5-code", json={"code": code}, headers={"Accept-Language": language})

    superseded, code = issue(), issue()
    assert redeem(superseded).status_code == 401
    with ThreadPoolExecutor(max_workers=2) as callers:
        responses = list(callers.map(redeem, (code, code.lower())))
    assert sorted(result.status_code for result in responses) == [200, 401]
    session = next(result.json() for result in responses if result.status_code == 200)
    assert redeem(issue()).json()["user_id"] == session["user_id"]
    headers = {"Authorization": f"Bearer {session['token']}"}
    account = http.get("/api/auth/me", headers=headers).json()
    assert session["account"] == account == {"user_id": session["user_id"], "username": None, "kind": "h5"}
    assert http.get(f"{listing}/{foreign['id']}", headers=headers).status_code == 404
    first_page = http.get(listing, headers=headers).json()
    cursor = first_page["next_cursor"]
    last_page = http.get(listing, headers=headers, params={"before_created": cursor["created"], "before_id": cursor["id"]}).json()
    assert len(first_page["items"]) == 30 and last_page["next_cursor"] is None
    assert {r["id"] for r in first_page["items"] + last_page["items"]} == {first["id"], *(f"history-{n}" for n in range(1,31))}

    detail_path = f"{listing}/{first['id']}"
    free = http.get(detail_path, headers=headers).json()
    assert free["access"] == "preview" and free["preview"] and free["chapters"] == [] and free["plan"] is None
    order = http.post(source_path + "/payment", headers=source_headers).json()
    assert http.post(source_path + "/payment/simulate", headers=source_headers,
                     json={"reference": order["reference"]}).json() == {"paid": True}
    finish(http, app)
    paid = http.get(detail_path, headers=headers).json()
    assert paid["access"] == "full" and paid["full_state"] == "ready" and paid["chapters"] and paid["plan"]
    canonical = http.get(source_path, headers=source_headers).json()
    assert paid["chapters"] == canonical["chapters"] and paid["plan"] == canonical["plan"]

    later = create(source_headers, 2028)
    assert http.get(listing, headers=headers).json()["items"][0]["id"] == later["id"]
    assert http.get(f"{listing}/{later['id']}", headers=headers).json()["input"]["profile"]["language"] == language


def test_h5_app_login_expiration_and_failed_attempt_budget(client):
    http, app, _, _ = client
    result = preview(http)
    route = f"/api/life-reports/{result['id']}/app-login-code"
    expired = http.post(route, headers=HEADERS).json()["code"]
    with app.state.store.connect() as db:
        db.execute("UPDATE h5_app_login_codes SET expires=0")
    redeem = "/api/auth/h5-code"
    assert http.post(redeem, json={"code": expired}).status_code == 401
    valid = http.post(route, headers=HEADERS).json()["code"]
    for _ in range(7):
        assert http.post(redeem, json={"code": "AAAAAA"}).status_code == 401
    response = http.post(redeem, json={"code": valid})
    assert response.status_code == 429 and response.json()["code"] == "too_many_requests"
    with app.state.store.connect() as db:
        assert db.execute("SELECT COUNT(*) AS count FROM h5_app_login_codes WHERE active").fetchone()["count"] == 1


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
        stored = json.loads(db.execute("SELECT chart FROM life_reports WHERE id=%s", (result["id"],)).fetchone()["chart"])
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
            row = db.execute("SELECT full_state,lease_until FROM life_reports WHERE id=%s", (result["id"],)).fetchone()
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
    assert [row["count"] for row in counts] == [2, 2]


def test_unlimited_testing_allows_preview_and_full_report_after_shared_network_quota(client):
    http, app, calls, _ = client
    settings = app.state.life_reports.writer.settings
    settings.bazi_reports_per_minute = settings.bazi_reports_per_day = 0
    network = "network:" + app.state.store.hash("testclient")
    with app.state.store.connect() as db:
        db.cursor().executemany("INSERT INTO bazi_report_usage VALUES(%s,%s)", [(network, time.time())] * 100)
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
        repair_fields = bundle.get("correction", {}).get("fields", {})
        if model == "qwen3.7-plus":
            assert payload["response_format"]["type"] == "json_schema"
            schema = payload["response_format"]["json_schema"]["schema"]
            if repair_fields:
                assert set(schema["properties"]) == set(schema["required"]) == {"traits.0"}
            else:
                assert schema["properties"]["language"]["const"] == bundle["language"]
                assert schema["properties"]["reading"]["const"] == bundle["reading"]
            assert "translations" not in schema["properties"] and not schema["additionalProperties"]
            if bundle["stage"] == "chapter":
                assert {"example", "response"} <= set(schema["$defs"]["Insight"]["required"])
                ids = schema["$defs"]["Insight"]["properties"]["evidence_ids"]
                assert ids["minItems"] == ids["maxItems"] == 2
                assert set(ids["items"]["enum"]) == set(bundle["evidence"])
                assert [item["enum"] for item in ids["prefixItems"]] == [
                    bundle["citation_rules"]["topic_ids"], bundle["citation_rules"]["supporting_natal_ids"],
                ]
                assert schema["$defs"]["WatchPoint"]["properties"]["signals"]["items"]["minLength"] == 12
            elif bundle["stage"] == "plan":
                assert set(schema["$defs"]["Phase"]["properties"]["action_ids"]["items"]["enum"]) == set(bundle["source_actions"])
        else:
            assert payload["response_format"] == {"type": "json_object"}
        instructions = bundle.get("writing_rules", payload["messages"][0]["content"])
        schemas = [line for line in instructions.splitlines() if line.startswith("stage=")]
        assert len(schemas) == 1 and schemas[0].startswith(f"stage={bundle['stage']}:")
        model_calls.append(bundle["stage"])
        story = story_for(bundle)
        if len(model_calls) == 1:
            story["traits"][0]["evidence_ids"] = ["H99", "P_sun"]
        if repair_fields:
            assert repair_fields == {"traits.0": ["traits", 0]}
            story = {"traits.0": story["traits"][0]}
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
    assert rows[0]["error_code"] and all(row["error_code"] == "" for row in rows[1:])
    assert all(isinstance(row["duration_ms"], int) and row["duration_ms"] >= 0 for row in rows)
    assert all((row["prompt_tokens"], row["completion_tokens"], row["cached_tokens"], row["usage_received"]) == (100, 50, 20, 1) for row in rows)
    assert preview(http)["id"] == result["id"]
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    assert len(model_calls) == 8


@pytest.mark.parametrize("language,bad_repair", [("zh", "evidence"), ("th", "extra_field")])
def test_preview_repairs_only_the_rejected_paragraph_and_revalidates_the_merge(client, monkeypatch, language, bad_repair):
    http, app, _, _ = client
    app.state.life_reports.writer.config.model = "qwen3.7-plus"
    real_client = httpx.AsyncClient
    attempts, expected = [], {}

    def handler(request):
        payload = json.loads(request.content)
        bundle = json.loads(payload["messages"][1]["content"])
        story = story_for(bundle)
        if language == "th":
            story["summary"]["text"] = "ลองเริ่มจากสิ่งที่สำคัญกับคุณ แล้วคุยให้เข้าใจตรงกันก่อนเลือกวิธีลงมือที่ทำได้จริง"
            titles = ["เริ่มอย่างเข้าใจ", "เลือกอย่างมีจังหวะ", "พูดคุยอย่างชัดเจน"]
            text = "เมื่อสิ่งที่ต้องทำยังไม่ชัด คุณอาจอยากคุยให้เข้าใจตรงกันก่อนเริ่ม ลองถามว่าผลงานแบบไหนที่ต้องการ แล้วเลือกส่วนเล็กมาลองทำก่อน วิธีนี้ช่วยให้เตรียมตัวได้ แต่หากต้องเริ่มทดลองเร็ว อาจตกลงขอบเขตสั้น ๆ แล้วค่อยปรับจากสิ่งที่พบ หลังจากลองทำให้ทบทวนว่าวิธีไหนช่วยลดความสับสน และเก็บส่วนที่ได้ผลไว้ใช้ต่อไป"
            for index, trait in enumerate(story["traits"]):
                trait.update(title=titles[index], text=titles[index] + " " + text)
        expected.update(LifeWriter.validate(json.dumps(story, ensure_ascii=False), bundle))
        correction = bundle.get("correction")
        attempts.append(correction)
        if not correction:
            story["traits"][0]["text"] = ("先把事情说清楚再决定。" if language == "zh" else "ค่อย ๆ ดูสิ่งที่ทำได้ ") * 3
        else:
            assert correction["fields"] == {"traits.0": ["traits", 0]}
            schema = payload["response_format"]["json_schema"]["schema"]
            assert set(schema["properties"]) == set(schema["required"]) == {"traits.0"}
            assert not schema["additionalProperties"]
            draft = json.loads(correction["draft"])
            assert draft["summary"] == expected["summary"]
            assert draft["traits"][1:] == expected["traits"][1:]
            story = {"traits.0": story["traits"][0]}
            if len(attempts) == 2:
                if bad_repair == "evidence":
                    story["traits.0"]["evidence_ids"] = ["H99", "P_sun"]
                else:
                    story["summary"] = expected["summary"]
        return httpx.Response(200, json={"choices": [{"finish_reason": "stop", "message": {"content": json.dumps(story, ensure_ascii=False)}}]})

    monkeypatch.setattr(LifeWriter, "write", BaziReports.write)
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    response = http.post("/api/life-reports", json={"profile": {**PROFILE, "language": language}, "year": 2027}, headers={**HEADERS, "Accept-Language": language})
    assert response.status_code == 200, response.text
    result = response.json()
    assert result["preview_state"] == "ready" and len(attempts) == 3
    assert result["access"] == "preview" and result["chapters"] == []
    with app.state.store.connect() as db:
        saved = db.execute("SELECT preview FROM life_reports WHERE id=%s", (result["id"],)).fetchone()
        usage = db.execute("SELECT validated FROM report_model_usage ORDER BY id").fetchall()
    assert json.loads(saved["preview"])["story"] == expected
    assert [row["validated"] for row in usage] == [0, 0, 1]


def test_preview_schema_errors_identify_a_paragraph_but_root_errors_require_a_full_retry(client):
    http, _, calls, _ = client
    preview(http)
    bundle = calls[0]
    story = story_for(bundle)
    story["traits"][1]["title"] = []
    with pytest.raises(InvalidBaziReport) as failure:
        LifeWriter.validate(json.dumps(story, ensure_ascii=False), bundle)
    assert failure.value.repair_fields == {"traits.1": ["traits", 1]}
    story["unexpected"] = True
    with pytest.raises(InvalidBaziReport) as failure:
        LifeWriter.validate(json.dumps(story, ensure_ascii=False), bundle)
    assert failure.value.repair_fields == {}


def test_hundred_previews_queue_before_calculation_and_finish_with_32_workers(postgres_url, monkeypatch):
    from collections import Counter
    from backend.app import thai
    chart = thai.natal({**PROFILE, "birth_time": "09:30"})
    monkeypatch.setattr(thai, "natal", lambda profile: deepcopy(chart))
    settings = Settings(database_url=postgres_url, app_env="production", life_generation_concurrency=32,
                        life_requests_per_minute=120, bazi_reports_per_minute=0, bazi_reports_per_day=0,
                        providers={"qwen": ProviderConfig("test-key", "https://model.example/v1", "test")})
    app = create_app(settings)
    service = app.state.life_reports
    async def exercise():
        active = peak = 0
        languages = Counter()
        release, saturated = asyncio.Event(), asyncio.Event()
        async def write(self, bundle, **kwargs):
            nonlocal active, peak
            active += 1
            peak = max(peak, active)
            languages[bundle["language"]] += 1
            if active == 32:
                saturated.set()
            try:
                await release.wait()
                return story_for(bundle)
            finally:
                active -= 1
        monkeypatch.setattr(LifeWriter, "write", write)
        await service.calculation_slots.acquire()
        await service.calculation_slots.acquire()
        try:
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as http:
                async def submit(index):
                    language = "zh" if index % 2 == 0 else "th"
                    headers = {"X-Report-Key": f"queue32-synthetic-owner-{index:032d}", "Accept-Language": language}
                    response = await http.post("/api/life-reports?wait=false", headers=headers,
                                               json={"profile": {**PROFILE, "language": language}, "year": 2027})
                    assert response.status_code == 200, response.text
                    return response.json(), headers
                accepted = await asyncio.gather(*(submit(index) for index in range(100)))
                assert len({row["id"] for row, _ in accepted}) == 100
                assert all(row["chart"] is None and row["preview_state"] in ("queued", "generating") for row, _ in accepted)
                assert not languages
                service.calculation_slots.release()
                service.calculation_slots.release()
                await asyncio.wait_for(saturated.wait(), 30)
                assert peak == 32
                release.set()
                async with asyncio.timeout(40):
                    while True:
                        with app.state.store.connect() as db:
                            ready = db.execute("SELECT COUNT(*) AS total FROM life_reports WHERE preview_state='ready'").fetchone()["total"]
                        if ready == 100:
                            break
                        await asyncio.sleep(0.1)
                assert languages == {"zh": 50, "th": 50} and peak == 32
                row, headers = accepted[0]
                result = (await http.get(f"/api/life-reports/{row['id']}", headers=headers)).json()
                assert result["preview_state"] == "ready" and result["access"] == "preview"
                assert result["full_state"] == "not_started" and not result["chapters"]
                foreign = await http.get(f"/api/life-reports/{row['id']}", headers=accepted[1][1])
                assert foreign.status_code == 404
        finally:
            release.set()
            await service.close()
    asyncio.run(exercise())


def test_preview_queue_recovers_queued_and_expired_jobs_without_resubmission(client):
    from backend.app.life_reports import LifeReports
    http, app, calls, _ = client
    original = app.state.life_reports
    body = LifeInput(profile=PROFILE, year=2027)
    async def exercise():
        rows = [await original.create(body, f"restart-owner-{i}", "restart-network", wait=False) for i in range(2)]
        await original.close()
        original.update(rows[0]["id"], preview_state="generating", lease="crashed-worker", lease_until=time.time() - 1)
        recovered = LifeReports(app.state.store, original.settings, asyncio.Semaphore(4), asyncio.Semaphore(2))
        try:
            recovered.start()
            async with asyncio.timeout(15):
                while any(recovered.get(row["id"], f"restart-owner-{i}")["preview_state"] != "ready" for i, row in enumerate(rows)):
                    await asyncio.sleep(0.05)
            duplicate = await recovered.create(body, "restart-owner-0", "restart-network", wait=False)
            assert duplicate["id"] == rows[0]["id"] and duplicate["preview_state"] == "ready"
            assert len(calls) == 2
            with app.state.store.connect() as db:
                db.execute("UPDATE life_reports SET preview=NULL,preview_state='generating',preview_network='',"
                           "lease='old-worker',lease_until=%s WHERE id=%s", (time.time() - 1, rows[0]["id"]))
            retried = await asyncio.wait_for(recovered.create(body, "restart-owner-0", "restart-network"), 8)
            assert retried["id"] == rows[0]["id"] and retried["preview_state"] == "ready"
        finally:
            await recovered.close()
    http.portal.call(exercise)


def test_model_slot_wait_does_not_consume_generation_timeout(client, monkeypatch):
    http, app, calls, _ = client
    preview(http)
    writer = app.state.life_reports.writer
    monkeypatch.setattr(writer, "generation_timeout", 0.04)
    async def exercise():
        for _ in range(4):
            await writer.slots.acquire()
        task = asyncio.create_task(writer.generate(calls[0], "waiting-owner", "waiting-network"))
        try:
            await asyncio.sleep(0.09)
            assert not task.done()
        finally:
            for _ in range(4):
                writer.slots.release()
        assert (await task)["state"] == "ready"
    http.portal.call(exercise)


def test_preview_retries_transient_throttle_with_bounded_attempts(client, monkeypatch):
    http, _, _, _ = client
    attempts = []
    async def write(self, bundle, **kwargs):
        attempts.append(bundle["reading"])
        if len(attempts) == 1:
            error = InvalidBaziReport("upstream_status_429")
            error.retry_after = 0.01
            raise error
        return self.validate(json.dumps(story_for(bundle), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    assert preview(http)["preview_state"] == "ready"
    assert len(attempts) == 2


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
    assert [row["count"] for row in counts] == [1, 1]


def test_thai_preview_chapters_and_plan_use_the_same_validated_pipeline(client, monkeypatch):
    http, app, calls, _ = client
    async def write(self, bundle, **kwargs):
        calls.append(deepcopy(bundle))
        return self.validate(json.dumps(thai_story_for(bundle), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    response = http.post("/api/life-reports", json={"profile": {**PROFILE, "language": "th"}, "year": 2027}, headers=HEADERS)
    result = response.json()
    assert result["preview_state"] == "ready", result
    http.post(f"/api/life-reports/{result['id']}/unlock", json={}, headers=HEADERS)
    finish(http, app)
    full = http.get(f"/api/life-reports/{result['id']}", headers=HEADERS).json()
    assert full["full_state"] == "ready" and len(full["chapters"]) == 5
    assert full["plan"] and full["title"] == "รายงานชีวิต"


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
    assert unlocked["full_state"] in ("queued", "generating")

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


def test_two_second_long_preview_polling_respects_the_real_limiter_and_recovers(client, monkeypatch):
    from types import SimpleNamespace
    from backend.app import main as api_main

    http, app, calls, _ = client
    result = preview(http)
    service = app.state.life_reports
    with service.store.connect() as db:
        saved = db.execute("SELECT preview FROM life_reports WHERE id=%s", (result["id"],)).fetchone()["preview"]
    service.update(result["id"], preview=None, preview_state="generating", lease="slow-test-preview", lease_until=time.time() + 300)
    clock = [time.monotonic()]
    # Advance only the middleware clock, leaving asyncio and the report lease clock intact.
    monkeypatch.setattr(api_main, "time", SimpleNamespace(monotonic=lambda: clock[0], time=time.time))
    path = f"/api/life-reports/{result['id']}"
    for _ in range(36):
        clock[0] += 2
        response = http.get(path, headers=HEADERS)
        assert response.status_code == 200, response.text
        assert response.json()["preview_state"] == "generating"
        clock[0] += 0.05  # A request completes before the frontend starts its next two-second wait.
    service.update(result["id"], preview=saved, preview_state="ready", lease="", lease_until=0)
    clock[0] += 2
    done = http.get(path, headers=HEADERS)
    assert done.status_code == 200 and done.json()["preview_state"] == "ready"
    assert done.json()["full_state"] == "not_started" and len(calls) == 1

    for _ in range(31):
        limited = http.get(path, headers=HEADERS)
        if limited.status_code == 429:
            break
        assert limited.status_code == 200
    assert limited.status_code == 429
    wait = int(limited.headers["Retry-After"])
    assert 1 <= wait <= 60
    clock[0] += wait + 0.05
    resumed = http.get(path, headers=HEADERS)
    assert resumed.status_code == 200 and resumed.json()["preview_state"] == "ready"
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
        row = db.execute("SELECT lease,lease_until FROM life_reports WHERE id=%s", (result["id"],)).fetchone()
    assert row["lease"] == "renewed-preview" and row["lease_until"] > time.time()
