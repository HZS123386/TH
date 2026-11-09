import asyncio
from copy import deepcopy
import json

from fastapi.testclient import TestClient
import httpx
import pytest

from backend.app.bazi import calculate
from backend.app.bazi_reports import BaziReports, InvalidBaziReport, grounding, validate_story
from backend.app.bazi_localization import fact_summary
from backend.app.bazi_testing import copy_for
from backend.app.config import ProviderConfig, Settings
from backend.app.main import create_app
from backend.app.schemas import BaziTestInput, ProfileInput
from backend.tests.test_roxy_bazi import EXPECTED, PROFILE, fixture_for


TEXT = {
    "zh": ["你在{topic}上更看重成果是否可靠，先明确自己能承担的部分，再协调他人的期待。", "面对{topic}的变化，你可以保留试探空间，避免为了尽快定下来而忽略真实感受。", "你的优势在于愿意认真投入，但过于强调自己的节奏，可能让对方难以表达不同需要。", "处理{topic}时，先把双方认可的标准说清楚，再用共同完成的小任务确认协作方式。", "为{topic}保留可以调整的余地，遇到分歧先确认目标是否相同，再讨论具体做法。"],
    "en": ["In {topic}, you may prefer dependable results. Clarify what you can take responsibility for before matching other people's expectations.", "Changes in {topic} can be approached through small trials. Leave room for a genuine response rather than rushing into a fixed commitment.", "A willingness to commit is a useful strength. Insisting on a personal pace can also make it harder for others to express different needs.", "For {topic}, agree on a shared standard before starting a small task together. Use the outcome to discuss how to cooperate next.", "Keep room to adjust plans for {topic}. When differences arise, confirm the shared goal before discussing the practical approach."],
    "th": ["ในเรื่อง{topic} คุณอาจให้ความสำคัญกับผลงานที่เชื่อถือได้ ลองบอกสิ่งที่ตนรับผิดชอบได้ก่อนประสานความคาดหวังของคนรอบข้าง", "เมื่อ{topic}เปลี่ยนแปลง ลองเผื่อพื้นที่สำหรับการทดลองเล็กน้อย แทนการรีบตัดสินใจจนมองข้ามความรู้สึกที่แท้จริง", "ความตั้งใจทุ่มเทเป็นจุดแข็ง แต่การยึดจังหวะของตนมากเกินไปอาจทำให้ผู้อื่นบอกความต้องการที่แตกต่างได้ยาก", "สำหรับ{topic} ลองตกลงมาตรฐานร่วมกันก่อนเริ่มงานเล็กที่ทำด้วยกัน แล้วใช้ผลลัพธ์พูดคุยวิธีร่วมมือครั้งต่อไป", "เผื่อทางปรับแผนเรื่อง{topic} เมื่อเห็นต่างให้ทบทวนเป้าหมายร่วมกันก่อนคุยรายละเอียดวิธีทำ"],
    "vi": ["Trong {topic}, bạn có thể coi trọng kết quả đáng tin cậy. Hãy làm rõ phần trách nhiệm của mình trước khi điều chỉnh kỳ vọng của người khác.", "Những thay đổi trong {topic} có thể được tiếp cận bằng thử nghiệm nhỏ. Hãy chừa khoảng trống để nhận ra cảm xúc thực thay vì vội cam kết.", "Sự sẵn lòng đầu tư công sức là điểm mạnh, nhưng quá giữ nhịp riêng có thể khiến người khác khó nói ra nhu cầu khác biệt.", "Với {topic}, hãy thống nhất tiêu chuẩn chung trước khi cùng hoàn thành việc nhỏ. Dùng kết quả để bàn cách hợp tác tiếp theo.", "Hãy giữ khả năng điều chỉnh kế hoạch cho {topic}. Khi bất đồng xuất hiện, xác nhận mục tiêu chung trước khi bàn cách thực hiện."],
}
TOPICS = {
    "zh": dict(zip(("overview", "work", "money", "love", "family", "annual"), ("自我理解", "职业发展", "资源安排", "亲密相处", "家庭互动", "年度安排"))),
    "en": dict(zip(("overview", "work", "money", "love", "family", "annual"), ("personal understanding", "career planning", "financial planning", "relationships", "family life", "plans for the year"))),
    "th": dict(zip(("overview", "work", "money", "love", "family", "annual"), ("การเข้าใจตนเอง", "การทำงาน", "การเงิน", "ความสัมพันธ์", "ครอบครัว", "แผนประจำปี"))),
    "vi": dict(zip(("overview", "work", "money", "love", "family", "annual"), ("hiểu bản thân", "sự nghiệp", "tài chính", "tình cảm", "gia đình", "kế hoạch năm"))),
}


def story_for(bundle):
    language, reading = bundle["language"], bundle["reading"]
    related = bundle["topic_evidence"][0]
    def paragraph(index):
        return {"text": TEXT[language][index].format(topic=TOPICS[language][reading]), "evidence_ids": [related, "P3"]}
    translated = {"zh": "本项反映已经返回的关系含义。", "en": "This describes the returned relationship.", "th": "ข้อความนี้อธิบายความสัมพันธ์ที่คำนวณแล้ว", "vi": "Nội dung này mô tả mối liên hệ đã được tính."}
    return {"language": language, "reading": reading, "interpretation": [paragraph(0), paragraph(1)], "opportunities": [paragraph(2)], "advice": [paragraph(3), paragraph(4)], "translations": {key: translated[language] for key in bundle["translation_fields"]}}


@pytest.fixture
def client_with_writer(tmp_path, monkeypatch):
    requests, bundles = [], []
    state = {"mode": "normal"}
    real_client = httpx.AsyncClient
    def handler(request):
        requests.append(request)
        payload = json.loads(request.content)
        if request.url.host == "roxyapi.com":
            assert request.headers["x-api-key"] == "roxy-private-key"
            value = fixture_for(request.url.path.rsplit("/", 1)[-1], payload)
            if "pillars" in value:
                local = calculate(ProfileInput(**{**PROFILE, "birth_date": payload["date"], "birth_time": payload["time"][:5]}), "local")
                for row in value["pillars"]:
                    chars = local["pillars"][row["position"]]
                    row["stem"]["chinese"], row["branch"]["chinese"] = chars
                if state["mode"] == "conflict":
                    value["pillars"][3]["stem"]["chinese"], value["pillars"][3]["branch"]["chinese"] = "甲", "子"
                if state["mode"] == "wrong-master":
                    value["dayMaster"] = {"chinese": "甲", "element": "Wood"}
                if state["mode"] == "fake-hidden":
                    value["pillars"][2]["hiddenStems"] = [{"stem": {"chinese": "甲"}}]
            if "factors" in value:
                for factor, text in zip(value["factors"], ("Metal is prosperous in a Metal month", "2 of 4 branches store Metal", "1 of the 3 other stems support the day stem, and 2 of the 3 other branches spend it")):
                    factor["detail"] = text
            return httpx.Response(200, json=value)
        assert request.url.host == "model.example"
        assert request.headers["authorization"] == "Bearer model-private-key"
        assert "x-api-key" not in request.headers
        bundle = json.loads(payload["messages"][1]["content"])
        assert "Synthetic" not in json.dumps(bundle) and "Beijing" not in json.dumps(bundle)
        assert "1995-08-17" not in json.dumps(bundle)
        bundles.append(bundle)
        story = story_for(bundle)
        mode = state["mode"]
        if mode == "recursion":
            return httpx.Response(200, content=b"[" * 100000 + b"0" + b"]" * 100000, headers={"content-type": "application/json"})
        if mode == "sse-recursion":
            return httpx.Response(200, content=b"data: " + b"[" * 100000 + b"0" + b"]" * 100000 + b"\n\n", headers={"content-type": "text/event-stream"})
        if mode == "wrong-language":
            story["language"] = "en" if bundle["language"] != "en" else "zh"
        if mode == "wrong-topic":
            story["reading"] = "money" if bundle["reading"] != "money" else "work"
        if mode == "unknown-evidence":
            story["advice"][0]["evidence_ids"] = ["FAKE"]
        if mode == "mixed-vi":
            for index, row in enumerate([*story["interpretation"], *story["opportunities"], *story["advice"]]):
                row["text"] = TEXT["en"][index].format(topic="planning") + " tôi"
        if mode == "duplicate":
            story["advice"][0]["text"] = story["interpretation"][0]["text"]
        if mode == "wrong-fact":
            story["interpretation"][0]["text"] = "Your Day Master is Jia Wood and your day pillar is Jia Zi."
        if mode == "repair" and len(bundles) == 1:
            story["interpretation"][0]["text"] = "Your Day Master is Jia Wood and your day pillar is Jia Zi."
        if mode in ("sse", "incomplete-sse"):
            raw = json.dumps(story, ensure_ascii=False)
            packets = [{"choices": [{"delta": {"reasoning_content": "private reasoning"}}]}, {"choices": [{"delta": {"content": raw[:len(raw) // 2]}}]}, {"choices": [{"delta": {"content": raw[len(raw) // 2:]}, "finish_reason": "stop" if mode == "sse" else "length"}]}]
            return httpx.Response(200, text="".join("data: " + json.dumps(packet, ensure_ascii=False) + "\n\n" for packet in packets) + "data: [DONE]\n\n", headers={"content-type": "text/event-stream"})
        return httpx.Response(200, json={"choices": [{"finish_reason": "stop", "message": {"content": json.dumps(story, ensure_ascii=False)}}]})
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    settings = Settings(database_path=str(tmp_path / "reports.db"), roxy_enabled=True, roxy_api_key="roxy-private-key", providers={"qwen": ProviderConfig("model-private-key", "https://model.example/v1", "test-model")}, bazi_reports_per_minute=100, bazi_reports_per_day=100)
    with TestClient(create_app(settings)) as client:
        yield client, bundles, state, requests


def request_body(language="zh", reading="work", birth_date="1995-08-17"):
    return {"profile": {**PROFILE, "birth_date": birth_date, "language": language}, "source": "roxy", "topics": ["chart", "annual"] if reading == "annual" else ["chart", "strength"], "focus": "overview" if reading == "annual" else reading, "year": 2026}


def test_six_readings_are_themed_cached_and_grounded_in_actual_birth(client_with_writer):
    client, bundles, _, _ = client_with_writer
    paragraphs = []
    for reading in ("overview", "work", "money", "love", "family", "annual"):
        result = client.post("/api/bazi/test", json=request_body(reading=reading)).json()
        assert result["report"]["generation"]["state"] == "ready"
        assert [row["id"] for row in result["report"]["sections"]] == ["interpretation", "opportunities", "advice"]
        paragraphs.append(result["report"]["sections"][0]["paragraphs"])
        assert TOPICS["zh"][reading] in " ".join(result["report"]["sections"][-1]["paragraphs"])
        assert "roxy-private-key" not in json.dumps(result) and "model-private-key" not in json.dumps(result)
    assert len({json.dumps(row) for row in paragraphs}) == 6
    assert len(bundles) == 6
    repeated = client.post("/api/bazi/test", json=request_body()).json()
    assert repeated["report"]["generation"]["cached"] and len(bundles) == 6
    other = client.post("/api/bazi/test", json=request_body(birth_date="1996-03-12")).json()
    assert other["report"]["generation"]["state"] == "ready"
    assert bundles[-1]["evidence"]["P3"] != bundles[1]["evidence"]["P3"]


@pytest.mark.parametrize("language", ["zh", "en", "th", "vi"])
def test_report_and_calculation_text_use_the_requested_language(client_with_writer, language):
    client, bundles, _, _ = client_with_writer
    result = client.post("/api/bazi/test", json=request_body(language)).json()
    assert result["report"]["generation"]["state"] == "ready"
    assert result["report"]["language"] == language
    assert bundles[0]["language"] == language
    assert len(result["report"]["translations"]) == 3
    assert all(section["language"] == language for section in result["report"]["sections"])
    assert "editorial" not in json.dumps(result["report"]) and '"scope"' not in json.dumps(result["report"])


@pytest.mark.parametrize("mode", ["wrong-language", "wrong-topic", "unknown-evidence", "mixed-vi", "duplicate", "wrong-fact", "recursion", "sse-recursion", "incomplete-sse"])
def test_bad_writing_never_becomes_a_report_and_releases_pending(client_with_writer, mode):
    client, bundles, state, _ = client_with_writer
    state["mode"] = mode
    body = request_body("vi" if mode == "mixed-vi" else "en" if mode == "wrong-fact" else "zh")
    result = client.post("/api/bazi/test", json=body).json()
    assert result["report"]["generation"]["state"] == "unavailable"
    assert result["report"]["sections"] == []
    assert result["sources"]["roxy"]["chart"]["pillars"] == EXPECTED
    with client.app.state.store.connect() as db:
        assert db.execute("SELECT MAX(pending_until) FROM bazi_reports").fetchone()[0] == 0
    client.post("/api/bazi/test", json=body)
    assert len(bundles) == (1 if mode in ("recursion", "sse-recursion", "incomplete-sse") else 2)


@pytest.mark.parametrize("mode", ["conflict", "wrong-master"])
def test_conflicting_calculation_cannot_reach_the_writer(client_with_writer, mode):
    client, bundles, state, _ = client_with_writer
    state["mode"] = mode
    result = client.post("/api/bazi/test", json=request_body()).json()
    assert result["report"]["generation"]["state"] in ("conflict", "calculation_unavailable")
    assert not bundles


def test_local_only_and_unknown_time_never_make_paid_writing_calls(client_with_writer):
    client, bundles, _, requests = client_with_writer
    body = request_body()
    body.update(source="github", topics=["chart"])
    assert client.post("/api/bazi/test", json=body).json()["report"]["generation"]["state"] == "unconfigured"
    body["source"], body["profile"]["birth_time"] = "roxy", None
    assert client.post("/api/bazi/test", json=body).json()["report"]["generation"]["state"] == "time_required"
    assert not bundles and not requests


@pytest.mark.parametrize("mode", ["sse", "fake-hidden"])
def test_streamed_writing_and_derived_hidden_stems_are_safe(client_with_writer, mode):
    client, bundles, state, _ = client_with_writer
    state["mode"] = mode
    result = client.post("/api/bazi/test", json=request_body()).json()
    assert result["report"]["generation"]["state"] == "ready"
    assert bundles[0]["evidence"]["D0"] == {"chinese": "庚", "element": "金"}
    assert [row["stem"] for row in bundles[0]["evidence"]["T3"]["hiddenStems"]] == ["戊", "乙", "癸"]


def test_writing_limit_does_not_call_model(client_with_writer):
    client, bundles, _, _ = client_with_writer
    client.app.state.bazi_reports.settings.bazi_reports_per_minute = 1
    assert client.post("/api/bazi/test", json=request_body()).json()["report"]["generation"]["state"] == "ready"
    result = client.post("/api/bazi/test", json=request_body("en")).json()
    assert result["report"]["generation"]["state"] == "limited"
    assert len(bundles) == 1


def test_zero_report_limits_allow_repeated_runs_with_existing_usage(client_with_writer):
    client, _, _, _ = client_with_writer
    writer = client.app.state.bazi_reports
    writer.settings.bazi_reports_per_minute = writer.settings.bazi_reports_per_day = 0
    for _ in range(100):
        assert writer.reserve_run("testing-owner", "testing-network")


def test_invalid_candidate_is_repaired_once_without_repeating_calculation(client_with_writer):
    client, bundles, state, requests = client_with_writer
    state["mode"] = "repair"
    result = client.post("/api/bazi/test", json=request_body("en")).json()
    assert result["report"]["generation"]["state"] == "ready"
    assert result["report"]["generation"]["attempts"] == 2
    assert len(bundles) == 2
    assert "correction" in bundles[1]
    assert sum(request.url.host == "roxyapi.com" for request in requests) == 2
    assert "Jia Wood" not in json.dumps(result["report"])


def test_concurrent_equal_writing_is_coalesced_and_cancellation_does_not_repeat_payment(client_with_writer, monkeypatch):
    client, _, _, _ = client_with_writer
    writer = client.app.state.bazi_reports
    body = BaziTestInput(**request_body())
    local = calculate(body.profile, "local")
    bundle = grounding(body, {}, local)
    calls = []
    async def write(value):
        calls.append(value)
        await asyncio.sleep(0.03)
        return validate_story(json.dumps(story_for(value), ensure_ascii=False), value)
    monkeypatch.setattr(BaziReports, "write", lambda self, value: write(value))
    async def run():
        first = asyncio.create_task(writer.generate(bundle, "one", "network"))
        await asyncio.sleep(0)
        second = asyncio.create_task(writer.generate(bundle, "one", "network"))
        first.cancel()
        with pytest.raises(asyncio.CancelledError):
            await first
        assert (await second)["state"] == "ready"
        assert (await writer.generate(bundle, "one", "network"))["cached"]
    asyncio.run(run())
    assert len(calls) == 1


def test_foreign_day_master_claims_are_rejected_even_with_existing_evidence(client_with_writer):
    body = BaziTestInput(**request_body())
    local = calculate(body.profile, "local")
    bundle = grounding(body, {}, local)
    for language, text in (("zh", "你的日主是甲木，所以在工作中会表现得非常主动。"), ("en", "Your Day Master is Jia Wood and your day pillar is Jia Zi."), ("vi", "Nhật chủ của bạn thuộc Mộc nên cần chủ động trong sự nghiệp."), ("th", "ดิถีของคุณเป็นธาตุไม้จึงควรแสดงความคิดในที่ทำงาน")):
        value = deepcopy(bundle)
        value["language"] = language
        story = story_for(value)
        story["interpretation"][0]["text"] = text
        with pytest.raises(InvalidBaziReport, match="calculation_in_prose"):
            validate_story(json.dumps(story, ensure_ascii=False), value)


@pytest.mark.parametrize("language,text", [("zh", "你的命局偏弱，因此处理事务时应先安排好合作边界，再逐步扩大承担的责任。"), ("en", "Your chart is weak, so arrange support before taking responsibility."), ("vi", "Mệnh của bạn yếu nên cần xác định trách nhiệm trước khi nhận thêm công việc."), ("th", "พื้นดวงของคุณอ่อนจึงควรตกลงหน้าที่ร่วมกันก่อนรับงานเพิ่ม")])
def test_contradictory_strength_claim_cannot_override_calculated_facts(language, text):
    body = BaziTestInput(**request_body(language))
    local = calculate(body.profile, "local")
    bundle = grounding(body, {}, local)
    story = story_for(bundle)
    story["interpretation"][0]["text"] = text
    with pytest.raises(InvalidBaziReport, match="calculation_in_prose"):
        validate_story(json.dumps(story, ensure_ascii=False), bundle)


def test_annual_evidence_is_displayed_even_if_referenced_third_or_after_duplicates():
    body = BaziTestInput(**request_body(reading="annual"))
    local = calculate(body.profile, "local")
    raw = fixture_for("annual-forecast", {"date": "1995-08-17", "time": "10:30:00", "year": 2026})
    bundle = grounding(body, {"roxy": {"chart": local, "details": {"annual": {"data": raw}}}}, local)
    story = story_for(bundle)
    for paragraph in [*story["interpretation"], *story["advice"]]:
        paragraph["evidence_ids"] = ["P3", "P3", "A0"]
    value = validate_story(json.dumps(story, ensure_ascii=False), bundle)
    assert value["interpretation"][0]["evidence_ids"] == ["A0", "P3"]
    assert "2026" in fact_summary(bundle, ["P3", "P3", "A0"], "zh", {}, copy_for("zh"))
