import json

import httpx
import pytest
from fastapi.testclient import TestClient

from backend.app import thai
from backend.app.config import ProviderConfig, Settings
from backend.app.main import create_app
from backend.app.schemas import ThaiReadingInput
from backend.app.thai_readings import InvalidThaiReport, calculation_in_prose, grounding, validate_story

PROFILE = {"display_name": "SyntheticPrivateName", "birth_date": "1995-08-17", "birth_time": "09:30", "timezone": "Asia/Bangkok", "birthplace": "Bangkok", "language": "en"}
TEXT = {
    "en": ["You may prefer a clear contribution over constant attention. A role with room for independent preparation can help you bring useful ideas into cooperation.", "When expectations compete, you may need time to consider the practical details. Explain what you can deliver before agreeing to a shared commitment.", "Careful preparation can support consistent results, while holding every detail alone may slow collaboration. Notice which responsibilities can be shared.", "Agree on a clear definition of a finished task with a collaborator, then compare the result together. This makes your contribution easier to recognize.", "Try a small version of an unfamiliar responsibility before accepting a larger commitment. This gives you practical information for deciding how much support you need."],
    "zh": ["你可能更重视能被看见的实际贡献，也愿意在充分准备后再表达想法。为自己的工作保留独立思考的空间，有助于在合作中发挥长处。", "当多方期待同时出现时，你可能需要先弄清楚实际细节，再决定如何承诺。把自己能承担的部分说清楚，有助于保持稳定的投入。", "细致准备有助于持续交付，但把所有细节都留给自己，也可能拖慢合作。可以留意哪些责任值得共同分担。", "开始合作前，先与对方确定怎样才算完成，再一起回看实际交付。这能让你的贡献更容易被理解，也减少反复修改。", "面对陌生的责任，可以先尝试范围较小的任务，再决定是否扩大投入。实际体验会帮助你判断需要哪些支持。"],
    "th": ["คุณอาจให้ความสำคัญกับผลงานที่จับต้องได้และชอบเตรียมความคิดก่อนพูด การมีพื้นที่ทำงานด้วยตนเองช่วยให้แบ่งปันสิ่งที่ถนัดกับผู้อื่นได้ดีขึ้น", "เมื่อมีความคาดหวังหลายทาง คุณอาจต้องการเวลาพิจารณารายละเอียด ลองบอกส่วนที่รับผิดชอบได้ก่อนรับปากเพื่อให้ร่วมมือกันได้อย่างต่อเนื่อง", "การเตรียมตัวช่วยให้งานสม่ำเสมอ แต่การดูแลทุกรายละเอียดคนเดียวอาจทำให้ความร่วมมือล่าช้า ลองพิจารณาว่าส่วนใดแบ่งหน้าที่กันได้", "ก่อนทำงานร่วมกันให้ตกลงว่าแบบไหนถือว่าเสร็จ แล้วทบทวนผลงานด้วยกัน วิธีนี้ช่วยให้ผู้อื่นเห็นคุณค่าของสิ่งที่คุณทำชัดขึ้น", "ลองรับงานที่ไม่คุ้นเคยในขอบเขตเล็กก่อนเพิ่มความรับผิดชอบ ประสบการณ์ตรงช่วยให้ตัดสินใจได้ว่าต้องการการสนับสนุนแบบใด"],
    "vi": ["Bạn có thể coi trọng đóng góp cụ thể và thích chuẩn bị trước khi trình bày. Không gian suy nghĩ độc lập giúp bạn đưa ý tưởng hữu ích vào hợp tác.", "Khi nhiều kỳ vọng cùng xuất hiện, bạn có thể cần xem xét chi tiết thực tế. Hãy nói rõ phần việc có thể đảm nhận trước khi cam kết cùng người khác.", "Chuẩn bị cẩn thận giúp duy trì kết quả, nhưng tự giữ mọi chi tiết có thể làm hợp tác chậm lại. Hãy cân nhắc những trách nhiệm có thể chia sẻ.", "Trước khi hợp tác, hãy thống nhất thế nào là hoàn thành rồi cùng xem lại kết quả. Cách này giúp người khác hiểu rõ đóng góp của bạn.", "Hãy thử trách nhiệm chưa quen ở phạm vi nhỏ trước khi nhận thêm. Trải nghiệm thực tế giúp bạn biết mình cần sự hỗ trợ như thế nào."],
}
SUMMARIES = {
    "zh": "先想清楚自己能承担什么，再把工作安排和合作分工说清楚。",
    "en": "Choose work with room to prepare, and agree on responsibilities before taking on more.",
    "th": "เลือกงานที่มีเวลาเตรียมตัว และตกลงหน้าที่ให้ชัดก่อนรับงานเพิ่ม",
    "vi": "Hãy chọn việc có thời gian chuẩn bị và thống nhất trách nhiệm trước khi nhận thêm.",
}
TITLES = {
    "zh": ["留出准备时间", "先说清楚承诺", "别把事情都揽下", "一起确定完成标准", "先试再扩大投入"],
    "en": ["Make room to prepare", "Be clear about commitments", "Share the responsibilities", "Agree on a finished result", "Try a smaller task first"],
    "th": ["เผื่อเวลาเตรียมตัว", "บอกสิ่งที่รับปากได้", "แบ่งความรับผิดชอบ", "ตกลงว่างานเสร็จแบบไหน", "เริ่มจากงานเล็กก่อน"],
    "vi": ["Dành thời gian chuẩn bị", "Nói rõ điều có thể làm", "Chia sẻ trách nhiệm", "Thống nhất kết quả cần có", "Thử việc nhỏ trước"],
}
DETAILS = {
    "zh": [
        {"steps": ["开始前把手头的任务写在纸上，圈出最需要先完成的事情。", "和一起做事的人确认各自负责哪一部分，再确定交接方式。", "完成后一起核对原来的要求，把需要补充的地方记下来。"], "example": "可以这样问对方：这件事我负责整理，你负责核对，做好以后我们一起检查，可以吗？"},
        {"steps": ["遇到不熟悉的任务时，先挑选其中容易试做的一小部分。", "做完这一部分后，把卡住的地方和需要的帮助说清楚。", "确认自己能承担的范围，再与对方讨论是否继续增加任务。"], "example": "如果有人请你负责新项目，可以先说：我想先试做一部分，再一起看看接下来怎么安排。"},
    ],
    "en": [
        {"steps": ["Write down the tasks already waiting and mark which needs attention before the others.", "Ask your collaborator to agree on who prepares the work and who checks it.", "Compare the finished work with the agreed result and note what still needs attention."], "example": "You could ask a colleague to prepare the notes while you check them, then review the finished work together."},
        {"steps": ["Choose a small part of the unfamiliar task that you can try without accepting everything.", "After trying it, explain what was difficult and ask for the specific help you need.", "Use that experience to agree on a manageable amount of work before expanding your responsibility."], "example": "When asked to take on an unfamiliar project, offer to try a small part before agreeing to manage the whole task."},
    ],
    "th": [
        {"steps": ["เขียนงานที่มีอยู่แล้วลงในกระดาษ แล้วเลือกงานที่ต้องทำให้เสร็จก่อนงานอื่น", "คุยกับคนที่ทำงานด้วยกันให้ชัดว่าใครเตรียมงานและใครตรวจงาน", "เมื่องานเสร็จให้เทียบกับสิ่งที่ตกลงกัน แล้วจดส่วนที่ยังต้องแก้ไข"], "example": "ลองถามเพื่อนร่วมงานว่าคุณเตรียมข้อมูลและให้อีกฝ่ายตรวจ จากนั้นค่อยดูผลงานด้วยกันได้ไหม"},
        {"steps": ["เลือกส่วนเล็กของงานที่ไม่คุ้นเคยมาลองทำก่อน โดยยังไม่รับทุกอย่าง", "เมื่อลองแล้วให้บอกว่าติดขัดตรงไหน และขอความช่วยเหลือที่จำเป็น", "ใช้ประสบการณ์ที่ลองทำมาคุยว่ารับผิดชอบได้แค่ไหนก่อนรับงานเพิ่ม"], "example": "หากมีคนชวนดูแลโครงการใหม่ ลองบอกว่าขอเริ่มจากงานบางส่วนก่อนแล้วค่อยตกลงหน้าที่ต่อไป"},
    ],
    "vi": [
        {"steps": ["Viết các việc đang chờ ra giấy rồi chọn việc cần hoàn thành trước những việc khác.", "Trao đổi với người cùng làm để thống nhất ai chuẩn bị và ai kiểm tra kết quả.", "Khi hoàn thành hãy so với điều đã thống nhất rồi ghi lại phần cần bổ sung."], "example": "Bạn có thể đề nghị mình chuẩn bị ghi chú còn đồng nghiệp kiểm tra, sau đó cùng xem lại kết quả."},
        {"steps": ["Chọn phần nhỏ của việc chưa quen để thử trước khi nhận toàn bộ trách nhiệm.", "Sau khi thử hãy nói rõ điều còn khó và nhờ hỗ trợ đúng phần đang cần.", "Dùng trải nghiệm đó để thống nhất khối lượng phù hợp trước khi nhận thêm công việc."], "example": "Khi được mời phụ trách dự án lạ, bạn có thể xin thử một phần trước rồi cùng bàn cách phân công tiếp."},
    ],
}


def story_for(bundle):
    language = bundle["language"]
    related = ["M1_sun", "M5_jupiter", "M9_saturn"] if bundle["reading"] == "annual" else bundle["topic_evidence"]
    extra_titles = {"zh": ["先把任务分清楚", "试着安排交流", "给计划留出余地", "完成后一起核对"],
                    "en": ["Share the task clearly", "Arrange a simple conversation", "Leave room to adjust", "Check the result together"],
                    "th": ["แบ่งงานให้ชัดก่อนเริ่ม", "ลองนัดเวลาคุยกัน", "เผื่อทางปรับแผนไว้", "ตรวจผลงานร่วมกัน"],
                    "vi": ["Phân công rõ trước khi làm", "Sắp xếp cuộc trao đổi", "Chừa khoảng trống điều chỉnh", "Cùng kiểm tra kết quả"]}
    def row(index):
        title = TITLES[language][index] if index < 5 else extra_titles[language][index - 5]
        text = TEXT[language][index % 5] if index < 5 else title + ": " + TEXT[language][index % 5]
        return {"title": title, "text": text, "evidence_ids": [related[index % len(related)], "P_sun"]}
    watches = []
    for index in range(3):
        item = row(index + 2)
        detail = DETAILS[language][index % 2]
        prefix = item["title"] + ": "
        watches.append({**item, "signals": [prefix + text for text in detail["steps"][:2]], "response": prefix + TEXT[language][0], "example": prefix + detail["example"]})
    advice = []
    for index in range(4):
        item = row(index + 5)
        detail = DETAILS[language][index % 2]
        prefix = item["title"] + ": "
        advice.append({**item, "steps": [prefix + text for text in detail["steps"]] + [prefix + TEXT[language][4]], "example": prefix + detail["example"],
                       "pitfall": {"zh": "需要留意：", "en": "Take care: ", "th": "สิ่งที่ควรใส่ใจ: ", "vi": "Cần lưu ý: "}[language] + prefix + TEXT[language][2], "check": prefix + SUMMARIES[language]})
    return {"language": language, "reading": bundle["reading"], "summary": {"text": SUMMARIES[language], "evidence_ids": [related[0], "P_sun"]}, "interpretation": [row(0), row(1)], "opportunities": watches, "advice": advice, "translations": {}}


@pytest.fixture
def client(tmp_path, monkeypatch):
    bundles = []
    mode = {"value": "ready"}
    real_client = httpx.AsyncClient
    def handler(request):
        assert request.url.host == "model.example"
        payload = json.loads(request.content)
        assert "Thai Suriyayatra" in payload["messages"][0]["content"]
        assert request.headers["authorization"] == "Bearer private-test-key"
        bundle = json.loads(payload["messages"][1]["content"])
        bundles.append(bundle)
        serialized = json.dumps(bundle)
        assert PROFILE["display_name"] not in serialized and PROFILE["birth_date"] not in serialized
        assert "Bangkok" not in serialized.replace("Asia/Bangkok", "")
        story = story_for(bundle)
        if mode["value"] == "bad-fact":
            story["interpretation"][0]["text"] = "Your Sun is in Aries in house 10, so you will get a new job."
        elif mode["value"] == "repair" and "correction" not in bundle:
            story["advice"][0]["evidence_ids"] = ["FAKE"]
        elif mode["value"] == "repair-language" and "correction" not in bundle:
            story["advice"][0]["steps"][0] = "先用 Excel 整理本次任务的清单，确定每项是否完成。"
        elif mode["value"] == "failed":
            return httpx.Response(503)
        return httpx.Response(200, json={"choices": [{"finish_reason": "stop", "message": {"content": json.dumps(story, ensure_ascii=False)}}]})
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    settings = Settings(database_path=str(tmp_path / "thai-readings.db"), providers={"qwen": ProviderConfig("private-test-key", "https://model.example/v1", "test")}, bazi_reports_per_minute=100, bazi_reports_per_day=100)
    with TestClient(create_app(settings)) as test_client:
        yield test_client, bundles, mode


@pytest.mark.parametrize("reading", ["overview", "money", "love", "work", "family", "annual"])
def test_topic_selects_actual_natal_houses_and_not_bazi(client, reading):
    http, bundles, _ = client
    response = http.post("/api/thai-reading", json={"profile": PROFILE, "reading": reading, "year": 2026})
    assert response.status_code == 200
    result = response.json()
    assert result["report"]["generation"]["state"] == "ready"
    assert len(result["report"]["sections"]) == 3
    assert result["natal"]["status"] == "ready" and result["natal"]["engine"]["name"] == "thai-astrology"
    assert "pillars" not in result and "roxy" not in result
    assert "private-test-key" not in response.text
    bundle = bundles[-1]
    for key, fact in bundle["evidence"].items():
        if fact["type"] == "house":
            expected = result["natal"]["chart"]["houses"][fact["number"] - 1]
            assert fact["ruler"] == expected["ruler"]["key"] and fact["ruler_house"] == expected["ruler"]["house"]
    if reading == "work":
        assert bundle["topic_evidence"] == ["H10", "H6", "H3", "H11"]
    elif reading == "love":
        assert bundle["topic_evidence"] == ["H7", "H5", "H1", "H4"]
    elif reading == "annual":
        assert {bundle["evidence"][key]["month"] for key in bundle["topic_evidence"]} == set(range(1, 13))
        assert result["report"]["sections"][0]["items"][0]["period"] == {"year": 2026, "month": 1}
    assert "evidence_ids" not in json.dumps(result["report"]["sections"])
    assert http.get("/api/profile").status_code == 401


@pytest.mark.parametrize("language", ["zh", "en", "th", "vi"])
def test_requested_language_is_used_in_facts_headings_and_prose(client, language):
    http, bundles, _ = client
    result = http.post("/api/thai-reading", json={"profile": {**PROFILE, "language": language}, "reading": "work"}).json()
    assert result["report"]["generation"]["state"] == "ready"
    assert result["report"]["language"] == language
    assert result["report"]["summary"] == SUMMARIES[language]
    assert result["report"]["sections"][0]["items"][0]["text"] == TEXT[language][0]
    assert result["report"]["sections"][0]["items"][0]["title"] == TITLES[language][0]
    assert bundles[-1]["language"] == language


def test_cache_changes_with_subject_year_language_and_birth_data(client):
    http, bundles, _ = client
    body = {"profile": PROFILE, "reading": "work"}
    first = http.post("/api/thai-reading", json=body).json()
    repeat = http.post("/api/thai-reading", json=body).json()
    assert repeat["report"]["generation"]["cached"] is True
    assert len(bundles) == 1 and first["report_id"] == repeat["report_id"]
    other = http.post("/api/thai-reading", json={**body, "profile": {**PROFILE, "birth_time": "15:30"}}).json()
    assert other["report_id"] != first["report_id"]
    assert other["natal"]["chart"]["points"]["ascendant"] != first["natal"]["chart"]["points"]["ascendant"]
    assert bundles[-1]["evidence"] != bundles[0]["evidence"]
    http.post("/api/thai-reading", json={**body, "reading": "money"})
    http.post("/api/thai-reading", json={**body, "profile": {**PROFILE, "language": "th"}})
    assert len(bundles) == 4
    for year in (2026, 2027):
        result = http.post("/api/thai-reading", json={**body, "reading": "annual", "year": year}).json()
        assert result["report"]["generation"]["state"] == "ready"
        assert bundles[-1]["evidence"]["M1_sun"]["year"] == year


@pytest.mark.parametrize("patch", [{"birth_time": None}, {"birthplace": ""}, {"birthplace": "UnrecognizedSyntheticPlace"}])
def test_incomplete_inputs_do_not_spend_a_model_call_or_fabricate_a_chart(client, patch):
    http, bundles, _ = client
    response = http.post("/api/thai-reading", headers={"Accept-Language": "en-US"}, json={"profile": {**PROFILE, **patch}})
    assert response.status_code == 422
    assert response.json()["code"] == "thai_reading_details_required"
    assert bundles == []


@pytest.mark.parametrize("mode,expected,attempts", [("bad-fact", "unavailable", 2), ("failed", "unavailable", 1), ("repair", "ready", 2)])
def test_failed_or_fabricated_writing_has_no_fake_fallback_and_can_be_repaired(client, mode, expected, attempts):
    http, bundles, state = client
    state["value"] = mode
    result = http.post("/api/thai-reading", json={"profile": PROFILE}).json()
    assert result["natal"]["status"] == "ready"
    assert result["report"]["generation"]["state"] == expected
    assert len(bundles) == attempts
    assert bool(result["report"]["sections"]) == (expected == "ready")


def test_unconfigured_reading_still_returns_real_chart(tmp_path):
    with TestClient(create_app(Settings(database_path=str(tmp_path / "unconfigured.db")))) as http:
        result = http.post("/api/thai-reading", json={"profile": PROFILE}).json()
        assert result["natal"]["status"] == "ready"
        assert result["report"]["sections"] == []
        assert result["report"]["generation"]["state"] == "unconfigured"


def test_daily_annual_samples_cover_leap_year_and_actual_relative_houses():
    result = thai.annual(2024, 5)
    assert result[1]["days"] == 29
    for month in result:
        for states in month["states"].values():
            assert sum(row["samples"] for row in states) == month["days"]
            assert all(row["house"] == (row["sign"] - 5) % 12 + 1 for row in states)


def test_report_validator_rejects_wrong_language_unknown_facts_and_duplicate_prose():
    body = ThaiReadingInput(profile=PROFILE, reading="work")
    bundle = grounding(body, thai.natal(PROFILE), [])
    for kind in ("language", "unknown", "duplicate"):
        story = story_for(bundle)
        if kind == "language":
            story["advice"][0]["text"] = TEXT["zh"][0]
        elif kind == "unknown":
            story["advice"][0]["evidence_ids"] = ["FAKE"]
        else:
            story["advice"][0]["text"] = story["interpretation"][0]["text"]
        with pytest.raises(InvalidThaiReport):
            validate_story(json.dumps(story, ensure_ascii=False), bundle)


def test_annual_validation_counts_only_the_months_and_natal_facts_actually_displayed():
    body = ThaiReadingInput(profile=PROFILE, reading="annual", year=2026)
    natal = thai.natal(PROFILE)
    bundle = grounding(body, natal, thai.annual(2026, natal["chart"]["points"]["ascendant"]["sign"]))
    story = story_for(bundle)
    for row in [*story["interpretation"], *story["opportunities"], *story["advice"]]:
        row["evidence_ids"] = ["M1_sun", "M1_jupiter", "M2_sun", "P_sun"]
    with pytest.raises(InvalidThaiReport, match="thin_evidence"):
        validate_story(json.dumps(story), bundle)
    story["opportunities"][1]["evidence_ids"] = ["M5_jupiter", "P_sun"]
    story["advice"][1]["evidence_ids"] = ["M9_sun", "M1_jupiter", "M1_sun", "P_sun"]
    validated = validate_story(json.dumps(story), bundle)
    assert validated["interpretation"][0]["evidence_ids"] == ["M1_sun", "P_sun"]
    assert validated["advice"][1]["evidence_ids"] == ["M9_sun", "P_sun"]


@pytest.mark.parametrize("language,text", [
    ("en", "Your tenth house is completely empty, so you need to build a professional direction through independent work."),
    ("zh", "你的第十宫完全没有星体，所以需要通过独立工作建立职业方向，并且减少与他人的合作。"),
    ("th", "เรือนการงานของคุณไม่มีดาวอยู่เลย จึงควรสร้างแนวทางอาชีพด้วยการทำงานด้วยตนเองก่อนเริ่มร่วมมือกับผู้อื่น"),
    ("vi", "Cung nhà thứ mười của bạn hoàn toàn trống nên bạn cần xây dựng định hướng nghề nghiệp qua công việc độc lập."),
])
def test_prose_cannot_override_calculated_house_occupancy_even_with_spelled_out_numbers(language, text):
    body = ThaiReadingInput(profile={**PROFILE, "language": language}, reading="work")
    bundle = grounding(body, thai.natal(PROFILE), [])
    bundle["evidence"]["H10"]["occupants"] = ["jupiter"]
    story = story_for(bundle)
    story["interpretation"][0] = {"title": TITLES[language][0], "text": text, "evidence_ids": ["H10", "P_sun"]}
    with pytest.raises(InvalidThaiReport, match="calculation_in_prose"):
        validate_story(json.dumps(story, ensure_ascii=False), bundle)


@pytest.mark.parametrize("language,text", [
    ("en", "In April, you will receive a new professional opportunity and should prepare a firm plan for your work."),
    ("zh", "在四月至五月期间，你将遇到新的职业机会，可以提前规划个人发展方向并且安排重要合作。"),
    ("th", "ในเดือนเมษายนคุณจะได้รับโอกาสใหม่ในการทำงาน จึงควรเตรียมแผนสำหรับความรับผิดชอบที่เพิ่มขึ้นอย่างรอบคอบ"),
    ("vi", "Trong tháng tư bạn sẽ có cơ hội nghề nghiệp mới và nên chuẩn bị kế hoạch làm việc cụ thể để phát triển."),
])
def test_spelled_out_prediction_months_cannot_bypass_the_calculated_fact_boundary(language, text):
    body = ThaiReadingInput(profile={**PROFILE, "language": language}, reading="work")
    bundle = grounding(body, thai.natal(PROFILE), [])
    story = story_for(bundle)
    story["interpretation"][0]["text"] = text
    with pytest.raises(InvalidThaiReport, match="calculation_in_prose"):
        validate_story(json.dumps(story, ensure_ascii=False), bundle)


def test_public_reading_contains_plain_meanings_and_actions_without_calculated_fact_prefixes(client):
    http, _, _ = client
    result = http.post("/api/thai-reading", json={"profile": {**PROFILE, "language": "zh"}, "reading": "work"}).json()
    report = result["report"]
    assert report["summary"] == SUMMARIES["zh"]
    assert [len(section["items"]) for section in report["sections"]] == [2, 3, 4]
    public = json.dumps(report, ensure_ascii=False)
    for term in ("宫主", "落入", "木星", "土星", "领域", "evidence_ids", "H10", "P_sun"):
        assert term not in public
    for section in report["sections"]:
        assert all(item["period"] is None for item in section["items"])


@pytest.mark.parametrize("part", ["summary", "title", "jargon", "long"])
def test_plain_reading_rejects_technical_or_unreadable_public_content(part):
    body = ThaiReadingInput(profile={**PROFILE, "language": "zh"}, reading="work")
    bundle = grounding(body, thai.natal(PROFILE), [])
    story = story_for(bundle)
    if part == "summary":
        story["summary"]["text"] = "你的事业宫主星水星落在第十二宫，所以你更适合先做好计划。"
    elif part == "title":
        story["advice"][0]["title"] = "事业宫主星的作用"
    elif part == "jargon":
        story["advice"][0]["text"] = "你需要整合隐性能量，发挥潜意识的内在驱动，再为自己寻找新的方向。"
    else:
        story["advice"][0]["text"] = "开始合作前可以先明确责任和具体的完成时间，避免事后反复修改。" * 12
    with pytest.raises(InvalidThaiReport):
        validate_story(json.dumps(story, ensure_ascii=False), bundle)


@pytest.mark.parametrize("language,title", [("vi", "Take action"), ("zh", "Plan计划"), ("th", "Plan ahead"), ("en", "安排工作")])
def test_a_translated_body_cannot_hide_an_untranslated_title(language, title):
    body = ThaiReadingInput(profile={**PROFILE, "language": language}, reading="work")
    bundle = grounding(body, thai.natal(PROFILE), [])
    story = story_for(bundle)
    story["advice"][0]["title"] = title
    with pytest.raises(InvalidThaiReport, match="title_language"):
        validate_story(json.dumps(story, ensure_ascii=False), bundle)


@pytest.mark.parametrize("language,text", [
    ("en", "Your chart ruler suggests a need to understand its placement before deciding how to handle professional responsibilities."),
    ("zh", "你的星盘守护星需要结合命盘来理解，才能更好地决定如何安排工作。"),
    ("th", "ควรทำความเข้าใจพื้นดวงและทักษาก่อนตัดสินใจว่าจะจัดการความรับผิดชอบในการทำงานอย่างไร"),
    ("vi", "Bạn nên hiểu lá số và chủ tinh trước khi quyết định cách sắp xếp trách nhiệm trong công việc."),
    ("en", "May is a good time to take on a new responsibility and discuss your professional direction with collaborators."),
])
def test_summary_cannot_leak_method_jargon_or_an_unverified_month(language, text):
    body = ThaiReadingInput(profile={**PROFILE, "language": language}, reading="work")
    bundle = grounding(body, thai.natal(PROFILE), [])
    story = story_for(bundle)
    story["summary"]["text"] = text
    with pytest.raises(InvalidThaiReport, match="calculation_in_prose"):
        validate_story(json.dumps(story, ensure_ascii=False), bundle)


def test_english_modal_may_remains_available_for_plain_language():
    assert not calculation_in_prose("You may prefer to prepare before agreeing to another task.")
    assert not calculation_in_prose("May need more time to prepare")
    assert calculation_in_prose("May")
    assert calculation_in_prose("May brings new opportunities")


def test_a_standalone_month_title_cannot_hide_behind_an_ordinary_body():
    body = ThaiReadingInput(profile=PROFILE, reading="work")
    bundle = grounding(body, thai.natal(PROFILE), [])
    story = story_for(bundle)
    story["advice"][0]["title"] = "May"
    with pytest.raises(InvalidThaiReport, match="calculation_in_prose"):
        validate_story(json.dumps(story), bundle)


@pytest.mark.parametrize("part", ["missing_steps", "missing_example", "mixed_step", "invented_example"])
def test_detailed_advice_requires_complete_localized_steps_and_example(part):
    body = ThaiReadingInput(profile={**PROFILE, "language": "zh"}, reading="money")
    bundle = grounding(body, thai.natal(PROFILE), [])
    story = story_for(bundle)
    if part == "missing_steps":
        story["advice"][0].pop("steps")
    elif part == "missing_example":
        story["advice"][0].pop("example")
    elif part == "mixed_step":
        story["advice"][0]["steps"][1] = DETAILS["en"][0]["steps"][1]
    else:
        story["advice"][0]["example"] = "你的第十宫没有星体，因此可以直接按这个做法安排工作。"
    with pytest.raises(InvalidThaiReport):
        validate_story(json.dumps(story, ensure_ascii=False), bundle)


def test_ordinary_thai_action_words_do_not_become_false_planet_or_house_claims():
    assert not calculation_in_prose("ดาวน์โหลดรายการใช้จ่ายแล้วตรวจค่าใช้จ่ายในครัวเรือน")
    assert not calculation_in_prose("ทุกอาทิตย์ลองนัดคุยเรื่องงานบ้าน และทบทวนอีกครั้งในวันศุกร์")
    assert calculation_in_prose("ดาวอาทิตย์อยู่ในเรือนการงาน")
    assert not calculation_in_prose("หากความกระตือรือร้นลดลง ลองแบ่งงานออกเป็นส่วนเล็ก")
    assert not calculation_in_prose("คุณสามารถมีน้ำใจและบอกขอบเขตของตนเองได้พร้อมกัน")
    assert calculation_in_prose("มกร")
    assert calculation_in_prose("ลัคนามกรทำให้คุณเป็นแบบนี้")
    assert calculation_in_prose("คุณมีราศีมีน")


def test_ordinary_chinese_changes_are_not_mistaken_for_an_ascendant():
    assert not calculation_in_prose("如果日常开销持续上升，可以先核对哪些支出超出了原先约定。")
    assert not calculation_in_prose("留意收入上升时，你是否也承诺了更多难以按时完成的工作。")
    assert calculation_in_prose("你的上升星座影响外在表现。")
    assert calculation_in_prose("本命上升决定了你的行事方式。")
    assert calculation_in_prose("上升")


def test_long_reading_language_repair_identifies_the_untranslated_word(client):
    http, bundles, mode = client
    mode["value"] = "repair-language"
    result = http.post("/api/thai-reading", json={"profile": {**PROFILE, "language": "zh"}, "reading": "work"}).json()
    assert result["report"]["generation"]["state"] == "ready"
    assert result["report"]["generation"]["attempts"] == 2
    assert "Excel" in bundles[-1]["correction"]["feedback"]


def test_expanded_schema_correction_identifies_the_missing_field_without_dumping_inputs():
    body = ThaiReadingInput(profile={**PROFILE, "language": "zh"}, reading="work")
    bundle = grounding(body, thai.natal(PROFILE), [])
    story = story_for(bundle)
    story["opportunities"][0].pop("response")
    with pytest.raises(InvalidThaiReport) as caught:
        validate_story(json.dumps(story, ensure_ascii=False), bundle)
    assert "opportunities.0.response" in caught.value.feedback
    assert PROFILE["display_name"] not in caught.value.feedback


def test_long_report_correction_collects_dates_from_all_extended_fields():
    body = ThaiReadingInput(profile={**PROFILE, "language": "zh"}, reading="work")
    bundle = grounding(body, thai.natal(PROFILE), [])
    story = story_for(bundle)
    story["opportunities"][0]["response"] = "在四月先和一起做事的人确认安排，再确定各自负责的部分。"
    story["advice"][0]["example"] = "例如九月在合作开始之前，先问清楚哪些事情需要优先完成。"
    story["advice"][1]["check"] = "在 Excel 里检查今天列出的工作是否全部完成，再安排后续任务。"
    with pytest.raises(InvalidThaiReport) as caught:
        validate_story(json.dumps(story, ensure_ascii=False), bundle)
    assert "四月" in caught.value.feedback and "九月" in caught.value.feedback
    assert "Excel" in caught.value.feedback


def test_ordinary_self_reference_does_not_match_a_stem_branch_pair():
    assert not calculation_in_prose("如果自己未想清楚，可以先确认能够承担的范围。")
    assert calculation_in_prose("己未日柱决定了你面对责任时的表现。")
