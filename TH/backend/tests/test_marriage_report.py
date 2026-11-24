"""Marriage uses native Thai evidence and computes long-range timing only after unlock."""
import asyncio
from copy import deepcopy
from dataclasses import replace
from datetime import datetime
from zoneinfo import ZoneInfo
import json

from fastapi.testclient import TestClient
import httpx
import pytest

from backend.app import marriage_report, thai
from backend.app.bazi_reports import InvalidBaziReport, preview_review_deadline_context
from backend.app.config import ProviderConfig
from backend.app.life_report_content import LifeWriter
from backend.app.life_reports import LifeInput, LifeReports
from backend.app.main import create_app
from backend.app.storage import Storage
from backend.tests.test_roxy_astrology import HEADERS, PROFILE, settings


FREE_TEXT = {
    "needs": "你要对方给句准话，愿不愿意认真交往。平时两个人各忙各的，你能接受。",
    "reaction": "对方越含糊，你越容易追着问。问几次还没答复，你就不再主动发消息。",
    "trap": "你容易把对方每天主动找你聊天当成认真的信号。要是对方一次次取消见面，也不给新时间，这段关系就只剩手机上的几条消息。",
    "current": "现阶段先看行动能不能稳定下来。有人把安排定下来并照做，才值得增加投入。",
    "attracts": "你容易吸引想被认真听懂的人，他们愿意和你讲出平时没有机会说的话。",
    "drains": "只在方便时出现的人会消耗你。他们接受你的照顾，却很少为见面腾出时间。",
}

THAI_FREE_TEXT = {
    "needs": "คุณอยากรู้ว่าอีกฝ่ายตั้งใจคบกันจริงแค่ไหน คำตอบที่ชัดช่วยให้คุณวางใจและใช้เวลาร่วมกันได้สบายขึ้น",
    "reaction": "เมื่ออีกฝ่ายพูดคลุมเครือ คุณจะถามซ้ำเพื่อให้แน่ใจ พอถามแล้วได้คำตอบเหมือนเดิม คุณมักหยุดชวนคุย",
    "trap": "คนที่คุยกับคุณทุกวันแต่เลื่อนนัดบ่อยทำให้ความสัมพันธ์ค้างอยู่ที่การส่งข้อความ ลองดูว่าเขาเสนอวันพบกันใหม่เองไหม",
    "current": "ลองตกลงเวลาสั้น ๆ ที่ทั้งคู่สะดวก แล้วดูว่าอีกฝ่ายทำตามที่รับปากหรือแจ้งให้รู้ทันทีเมื่อแผนเปลี่ยน",
    "attracts": "คุณมักดึงดูดคนที่ฟังเรื่องของคุณจนจบ เขาจะถามให้เข้าใจก่อนค่อยเล่าเรื่องของตัวเอง",
    "drains": "คนที่ปล่อยให้คุณจัดการนัดทุกครั้งทำให้คุณเสียเวลา โดยเฉพาะเมื่อเขารอจนถึงเวลานัดจึงบอกว่ามาไม่ได้",
}


@pytest.mark.parametrize("known", [False, True])
def test_marriage_preview_contract(known):
    allowed = {key: [f"source_{key}"] for key in FREE_TEXT}
    bundle = {
        "stage": "marriage_preview",
        "language": "zh",
        "reading": "marriage-preview",
        "birth_time_known": known,
        "allowed_evidence": allowed,
        "required_evidence": {},
    }
    draft = {"language": "zh", "reading": "marriage-preview", "field_sources": {"needs": "fake_source"}}
    draft.update({key: {"text": text} for key, text in FREE_TEXT.items()})
    draft["attracts"]["evidence_ids"] = " source_attracts "
    draft["drains"]["evidence_ids"] = ["source_drains", "source_drains"]
    if known:
        draft["current"]["state"] = "ready_to_assess"
    result = LifeWriter.validate(json.dumps(draft, ensure_ascii=False), bundle)
    assert result["current"]["state"] == ("ready_to_assess" if known else "observe")
    assert result["needs"]["evidence_ids"] == allowed["needs"]
    assert result["attracts"]["evidence_ids"] == allowed["attracts"]
    assert result["drains"]["evidence_ids"] == allowed["drains"]
    assert "field_sources" not in result

    draft["current"]["state"] = "observe" if known else "ready_to_assess"
    with pytest.raises(InvalidBaziReport, match="birth-time precision") as error:
        LifeWriter.validate(json.dumps(draft, ensure_ascii=False), bundle)
    assert error.value.repair_fields == {"current": ["current"]}

    del draft["trap"]
    with pytest.raises(InvalidBaziReport, match="malformed fields: trap") as error:
        LifeWriter.validate(json.dumps(draft, ensure_ascii=False), bundle)
    assert error.value.repair_fields == {"trap": ["trap"]}


@pytest.mark.parametrize("available_slots", [0, 1])
def test_marriage_preview_deadline_cancels_the_writer(monkeypatch, available_slots):
    service = LifeReports.__new__(LifeReports)
    monkeypatch.setattr(service, "marriage_preview_timeout", 0.05)
    finished, failed = [], []
    monkeypatch.setattr(marriage_report, "bundle", lambda body, chart: {"stage": "marriage_preview"})
    monkeypatch.setattr(service, "fail_preview", lambda report, lease: failed.append((report, lease)))
    body = LifeInput(profile=PROFILE, year=2026, report_kind="marriage")
    row = {"id": "test-report", "chart": "{}"}

    async def generate_preview():
        slots = asyncio.Semaphore(available_slots)
        writer = LifeWriter(None, settings("postgresql://localhost/fate_test_preview"), slots)
        writer_finished = asyncio.Event()
        model_calls = []

        async def write(bundle):
            model_calls.append(bundle["stage"])
            await asyncio.Event().wait()

        def finish(key, lease, story=None):
            finished.append((lease, story))
            writer_finished.set()

        monkeypatch.setattr(writer, "prompt", lambda bundle: "Test free preview")
        monkeypatch.setattr(writer, "claim", lambda key, owner, network: ("claimed", None, "writer-lease"))
        monkeypatch.setattr(writer, "write", write)
        monkeypatch.setattr(writer, "finish", finish)
        monkeypatch.setattr(service, "preview_writer_for", lambda language: writer)
        await service.write_preview(row, body, "test-owner", "test-network", "test-lease")
        await asyncio.wait_for(writer_finished.wait(), timeout=1)
        assert model_calls == ["marriage_preview"] * available_slots
        if available_slots:
            await asyncio.wait_for(slots.acquire(), timeout=1)

    asyncio.run(generate_preview())
    assert finished == [("writer-lease", None)]
    assert failed == [("test-report", "test-lease")]


def test_marriage_preview_uses_readable_draft_at_review_deadline(monkeypatch):
    draft = {"language": "zh", "reading": "marriage-preview"}
    draft.update({key: {"text": value} for key, value in FREE_TEXT.items()})
    draft["reaction"]["text"] = draft["needs"]["text"]
    bundle = {"stage": "marriage_preview", "language": "zh", "reading": "marriage-preview",
              "birth_time_known": False, "allowed_evidence": {key: ["source"] for key in FREE_TEXT},
              "required_evidence": {}}
    raw = json.dumps(draft, ensure_ascii=False)
    writes, saved = [], []

    async def generate():
        writer = LifeWriter(None, settings("postgresql://localhost/fate_test_preview"), asyncio.Semaphore(1))
        stopped = asyncio.Event()

        async def write(bundle, *, correction=None):
            writes.append(correction)
            if correction is None:
                try:
                    return writer.validate(raw, bundle)
                except InvalidBaziReport as error:
                    error.candidate = raw
                    raise
            try:
                await asyncio.Event().wait()
            finally:
                stopped.set()

        monkeypatch.setattr(writer, "prompt", lambda bundle: "Test preview")
        monkeypatch.setattr(writer, "claim", lambda key, owner, network: ("claimed", None, "writer-lease"))
        monkeypatch.setattr(writer, "finish", lambda key, lease, story=None: saved.append(story))
        monkeypatch.setattr(writer, "write", write)
        # Keep the real 15-second service setting and exercise the code with a short deadline.
        loop = asyncio.get_running_loop()
        token = preview_review_deadline_context.set(loop.time() + 0.12)
        try:
            result = await asyncio.wait_for(writer.generate(bundle, "owner", "network"), timeout=1)
            assert result["state"] == "ready"
            assert result["story"]["reaction"]["text"] == FREE_TEXT["needs"]
            assert stopped.is_set() and len(writes) == 2
            assert saved == [result["story"]]
            assert writer.validate(raw, bundle) == result["story"]

            draft["reaction"]["text"] = "This is an English paragraph in a Chinese free report."
            with pytest.raises(InvalidBaziReport, match="language"):
                writer.validate(json.dumps(draft, ensure_ascii=False), bundle)
            draft["reaction"]["text"] = FREE_TEXT["needs"]
            draft["reaction"]["evidence_ids"] = ["invented"]
            with pytest.raises(InvalidBaziReport, match="supplied evidence"):
                writer.validate(json.dumps(draft, ensure_ascii=False), bundle)
        finally:
            preview_review_deadline_context.reset(token)

    asyncio.run(generate())


FULL_TEXT = {
    "fit": "适合你的关系有清楚的分工，也能留出自己的空间。临时加班时，两个人能够重新安排见面，而不是靠一方一直等候。",
    "conflict": "长期问题容易出在累积的小失约。要是每次改时间都不了了之，讨论一次晚饭很快会变成争论谁比较在乎。",
    "supportive": "愿意把需要讲具体的人能发挥你擅长照顾细节的优点。他们会说明希望得到哪种协助，也会在你忙时承担自己的那部分。",
    "draining": "回避商量的人会让你总在猜测对方的安排。比如口头同意一起处理家务，却每次等你催促才回应。",
    "key_window": "可以把承诺谈具体。对方愿意和你约定平日相处的频率，并且遇到变化会主动协调，这时才适合一起讨论更长期的计划。",
    "contrast": "在外你可能习惯先把事情做稳，亲近之后却更期待对方主动读懂你的感受。这种落差会使对方看见你的可靠，却不容易知道你也需要照顾。",
    "planet_pattern": "你容易先从对方说话的方式感到亲近。判断能否走长久时，还要留意对方处理不同意见的态度，尤其是愿不愿意把同一件事谈完。",
    "present": "先谈现有的安排是否需要调整。你可以观察两人是否都愿意提出可行的时间，而非总由你来补足。",
    "period_one": "适合把共同兴趣转成实际见面。用能执行的安排辨认彼此是否都为认识对方留出了精力。",
    "period_two": "分歧容易出现在责任没有说清时。一次只讨论需要改变的那件事，观察双方能否提出具体的分担办法。",
    "period_three": "生活安排稳定后再考虑更深的共同责任。见家人或讨论住处之前，先确认两人的步调是否相近。",
    "career": "工作上可以先接下交付标准清楚的任务，让你擅长厘清细节的能力更容易被团队看见。",
    "money": "共同开销提前说好各自负责什么，想加一项新的支出时先商量目的和承担方式。",
    "wellbeing": "连续替别人处理问题时，给自己留一段可以不用回应消息的时间，先把当天真正需要休息的事处理好。",
    "selection": "选人时观察对方是否愿意协商一次你不方便的安排，再决定要不要交出更多时间。",
    "communication": "谈到见面时可以说，我希望这件事今天定下来，你哪天有空，我们一起确认。",
    "boundaries": "约好的事如果再次无故落空，就把原先预留的时间收回来。下一次由对方提出具体安排。",
    "other_action": "和同事确认任务的先后顺序。把共同开销按承担人写清楚。下班后留段不回复群消息的时间。",
    "support": "准备谈较难开口的一件事时，可以在纸上记下最想表达的需要，带去提醒自己把那句话讲完。",
    "takeaway": "走得长久的人，愿意把喜欢落实在双方都做得到的小事上。",
}


@pytest.mark.parametrize("known", [True, False])
def test_free_chart_batches_native_calculations_without_changing_evidence(known):
    profile = {**PROFILE, "birth_time": PROFILE["birth_time"] if known else None}
    start = datetime(2026, 11, 19, 12, tzinfo=ZoneInfo("Asia/Bangkok"))
    if known:
        original = thai.natal(profile)
        ascendant = original["chart"]["points"]["ascendant"]["sign"]
    else:
        original = {
            "status": "ready",
            "time_known": False,
            "sun_signs": thai.fortune(profile, "month", start)["birth"]["sun_signs"],
        }
        ascendant = None
    assert thai.marriage_preview_chart(profile, start.date()) == {
        **original,
        "provider": "thai",
        "reference_date": start.date().isoformat(),
        "marriage_recent": thai.marriage_windows(start.date(), 30, ascendant),
    }


@pytest.mark.parametrize("known", [True, False])
def test_marriage_report_uses_calculated_evidence_and_unlocks_only_full_edition(postgres_url, monkeypatch, known):
    calls, long_windows = [], []
    calculate_future = marriage_report.future_windows

    def track_future(chart):
        windows = calculate_future(chart)
        long_windows.append(windows)
        return windows

    async def write(self, bundle, **kwargs):
        calls.append(bundle)
        is_free = bundle["stage"] == "marriage_preview"
        prompt = self.prompt(bundle)
        writing_version = marriage_report.PREVIEW_VERSION if is_free else marriage_report.FULL_VERSION
        assert prompt.startswith(f"Write {writing_version},")
        assert ("field_sources" in prompt) == is_free
        assert ("rhetorical questions" in prompt) == is_free
        assert ("揪出搅局的人" in prompt) == is_free
        assert ("你习惯……" if is_free else "值得认真对待的人，会……") in prompt
        contract = self.response_format(bundle)["json_schema"]["schema"]
        paragraphs = FREE_TEXT if is_free else FULL_TEXT
        draft = {"language": "zh", "reading": bundle["reading"]}
        for key, text in paragraphs.items():
            allowed = bundle["allowed_evidence"][key]
            groups = bundle["required_evidence"].get(key, [])
            ids = list(dict.fromkeys(group[0] for group in groups)) or allowed[:1]
            draft[key] = {"text": text}
            if is_free:
                properties = contract["properties"][key]["properties"]
                if len(allowed) == 1:
                    assert "evidence_ids" not in properties
                    continue
                assert properties["evidence_ids"]["minItems"] == 1
                assert properties["evidence_ids"]["items"]["enum"] == allowed
            draft[key]["evidence_ids"] = ids
        if is_free:
            model_input = self.model_input(bundle)
            assert model_input["field_sources"]["needs"] == ("N0" if known else "P_sun")
            assert model_input["field_sources"]["current"] == bundle["allowed_evidence"]["current"]
            assert model_input["current_states"] == (list(marriage_report.STATES[:3]) if known else ["observe"])
            current_schema = contract["properties"]["current"]["properties"]
            if known:
                assert current_schema["state"]["enum"] == list(marriage_report.STATES[:3])
                draft["current"]["state"] = "ready_to_assess"
                draft["trap"]["evidence_ids"] = ["P_venus"]
            else:
                assert "state" not in current_schema
                draft["field_sources"] = model_input["field_sources"]
            illegal_state = deepcopy(draft)
            illegal_state["current"]["state"] = "observe" if known else "ready_to_assess"
            with pytest.raises(InvalidBaziReport, match="birth-time precision") as error:
                self.validate(json.dumps(illegal_state, ensure_ascii=False), bundle)
            assert error.value.repair_fields == {"current": ["current"]}
        invalid = deepcopy(draft)
        invalid["needs" if is_free else "period_two"]["evidence_ids"] = ["invented"]
        with pytest.raises(InvalidBaziReport, match="supplied evidence"):
            self.validate(json.dumps(invalid, ensure_ascii=False), bundle)
        if not is_free:
            repeated = deepcopy(draft)
            repeated["fit"]["text"] = bundle["free_reading"]["needs"]
            with pytest.raises(InvalidBaziReport, match="repeats free preview"):
                self.validate(json.dumps(repeated, ensure_ascii=False), bundle)
        story = self.validate(json.dumps(draft, ensure_ascii=False), bundle)
        if is_free:
            assert story["needs"]["evidence_ids"] == (["N0"] if known else ["P_sun"])
        return story

    async def unexpected_western(*args, **kwargs):
        pytest.fail("The marriage report must use the native Thai chart")

    monkeypatch.setattr(LifeWriter, "write", write)
    monkeypatch.setattr(marriage_report, "future_windows", track_future)
    with TestClient(create_app(settings(postgres_url))) as client:
        app = client.app.state.life_reports
        monkeypatch.setattr(app.adapters["astrology"], "calculate", unexpected_western)
        profile = {**PROFILE, "birth_time": PROFILE["birth_time"] if known else None}
        response = client.post("/api/life-reports", json={"report_kind": "marriage", "profile": profile, "year": 2026},
                               headers=HEADERS)
        assert response.status_code == 200, response.text
        free = response.json()
        assert free["preview_state"] == "ready", free
        assert free["version"] == marriage_report.PREVIEW_VERSION
        preview_sections = free["marriage"]["preview"]
        style, current = (section["paragraphs"] for section in preview_sections[1:3])
        assert [section["title"] for section in preview_sections if section.get("visible", True)] == [
            "基础信息", "上升在感情里的真实样子" if known else "你在感情里的相处倾向", "当前感情能量", "领取完整报告",
        ]
        assert style == [FREE_TEXT[key] for key in ("needs", "reaction", "trap")]
        assert current == ["现在具备认真看人的条件。" if known else "先观察实际相处。", FREE_TEXT["current"]]
        offer = free["marriage"]["preview"][-1]["paragraphs"]
        assert offer == marriage_report.COPY["zh"]["offer"].splitlines()
        assert len(offer) == 2
        assert offer[0] == "该断该续，先认清什么行为在搅局。"
        assert free["method"]["name"] == "Thai Suriyayatra"
        assert bool(free["chart"]) == known and free["time_accuracy"]["assumed_local_time"] is None
        assert free["marriage"]["full"] is None
        assert [section["key"] for section in free["marriage"]["preview"]] == list(marriage_report.PREVIEW)
        with app.store.connect() as db:
            saved_row = dict(db.execute("SELECT * FROM life_reports WHERE id=%s", (free["id"],)).fetchone())
        draft_row = {**saved_row, "preview": None,
                     "generation_progress": json.dumps(dict.fromkeys(
                         ("preview_summary", "preview_strength", "preview_decisions", "preview_relationships"), 85,
                     ))}
        generating = app.public({**draft_row, "preview_state": "generating"})
        failed = app.public({**draft_row, "preview_state": "unavailable"})
        assert generating["preview_generation_progress"]["percent"] == 85
        assert failed["preview_generation_progress"]["percent"] == 0
        assert [call["stage"] for call in calls] == ["marriage_preview"]
        assert not long_windows and not any(key.startswith("Y") for key in calls[0]["evidence"])
        report_path = f"/api/life-reports/{free['id']}"
        assert client.post(report_path + "/unlock", headers=HEADERS).status_code == 402
        if known:
            assert "H7" in calls[0]["evidence"]
        else:
            assert "N0" not in calls[0]["evidence"] and "H7" not in calls[0]["evidence"]
            assert all(row["house"] is None for row in calls[0]["evidence"].values() if row["type"] == "marriage_window")

        order = client.post(report_path + "/payment", headers=HEADERS, json={})
        assert order.status_code == 200
        assert not long_windows
        paid = client.post(report_path + "/payment/simulate", headers=HEADERS, json={"reference": order.json()["reference"]})
        assert paid.json()["paid"]

        async def finish():
            async with asyncio.timeout(16):
                while not app.tasks and len(calls) < 2:
                    await asyncio.sleep(.05)
                if app.tasks:
                    await asyncio.gather(*app.tasks.values())

        client.portal.call(finish)
        complete = client.get(report_path, headers=HEADERS).json()
        assert complete["full_state"] == "ready", complete
        assert [call["stage"] for call in calls] == ["marriage_preview", "marriage_full"]
        assert len(long_windows) == int(known)
        assert complete["progress"] == {"total": 8, "completed": 8}
        with app.store.connect() as db:
            row = db.execute("SELECT * FROM life_reports WHERE id=%s", (free["id"],)).fetchone()
        line_ready = {**row, "unlocked": 0, "line_confirmed_at": 1.0}
        assert app.public(line_ready)["marriage"]["full"] is None
        assert app.public(line_ready, line_delivery=True)["marriage"]["full"] == complete["marriage"]["full"]
        failed = app.public({**row, "full_state": "unavailable", "chapters": "{}",
                             "generation_progress": '{"marriage-full":95}'})
        assert failed["progress"] == {"total": 8, "completed": 0}
        assert failed["generation_progress"]["percent"] == 0
        assert failed["marriage"]["full"] is None
        sections = complete["marriage"]["full"]
        assert [section["key"] for section in sections] == list(marriage_report.FULL)
        assert sections[0]["paragraphs"] == [FULL_TEXT["contrast"]]
        assert FULL_TEXT["fit"] in sections[1]["paragraphs"]
        assert FULL_TEXT["contrast"] not in sections[2]["paragraphs"]
        assert FULL_TEXT["takeaway"] == sections[-1]["paragraphs"][-1]
        assert sections[4]["paragraphs"][:7] == [
            "工作 / 事业", FULL_TEXT["career"], "财运 / 资源", FULL_TEXT["money"], "自身状态", FULL_TEXT["wellbeing"], "预警信号",
        ]
        timing = sections[3]["paragraphs"]
        if known:
            for index, field in enumerate(marriage_report.FUTURE_FIELDS, 1):
                evidence_id = calls[1]["required_evidence"][field][0][0]
                assert evidence_id.startswith(f"Y{index}_")
                factor = calls[1]["evidence"][evidence_id]
                assert any(f"{factor['start']} – {factor['end']}" in paragraph for paragraph in timing)
        else:
            assert marriage_report.COPY["zh"]["timing_limit"] in timing
            assert not any(key.startswith("Y") for key in calls[1]["evidence"])

        # Earlier saved previews predate the stored writing version.
        with app.store.connect() as db:
            row = db.execute("SELECT preview FROM life_reports WHERE id=%s", (free["id"],)).fetchone()
            saved = json.loads(row["preview"])
            del saved["version"]
            opening = "每次都聊得很深，怎么心里还是没底？你在意的是两个人能把对这段关系的期待说清楚。"
            saved["story"]["needs"]["text"] = opening
            db.execute("UPDATE life_reports SET preview=%s WHERE id=%s", (json.dumps(saved), free["id"]))
        earlier = client.get(report_path, headers=HEADERS).json()
        assert earlier["version"] == "thai-marriage-1"
        earlier_style = earlier["marriage"]["preview"][1]["paragraphs"]
        assert earlier_style == [opening, *style[1:]]
        assert earlier["marriage"]["full"] == complete["marriage"]["full"]

        with app.store.connect() as db:
            row = db.execute("SELECT chapters FROM life_reports WHERE id=%s", (free["id"],)).fetchone()
            chapters = json.loads(row["chapters"])
            del chapters["marriage"]["version"]
            db.execute("UPDATE life_reports SET chapters=%s WHERE id=%s", (json.dumps(chapters), free["id"]))
        earlier_full = client.get(report_path, headers=HEADERS).json()["marriage"]["full"]
        assert earlier_full[0]["paragraphs"] == [marriage_report.COPY["zh"]["guide"]]
        assert FULL_TEXT["contrast"] in earlier_full[2]["paragraphs"]


@pytest.mark.parametrize("known", [True, False])
def test_preview_retries_only_one_invalid_point(postgres_url, monkeypatch, known):
    requests = []
    client_class = httpx.AsyncClient
    path = ["current"] if known else ["needs", "text"]
    field = "current" if known else "1"

    def respond(request):
        assert str(request.url) == "https://preview-model.example/v1/chat/completions"
        payload = json.loads(request.content)
        contract = payload["response_format"]["json_schema"]
        requests.append(contract["name"])
        context = json.loads(payload["messages"][1]["content"])
        if requests == ["life_marriage_preview"]:
            assert context["field_sources"]["needs"] == ("N0" if known else "P_sun")
            draft = {
                "language": "zh",
                "reading": "marriage-preview",
                **{key: {"text": value} for key, value in FREE_TEXT.items()},
            }
            draft["field_sources"] = context["field_sources"]
            for name, identifiers in context["field_sources"].items():
                if isinstance(identifiers, list):
                    draft[name]["evidence_ids"] = identifiers[:1]
            if known:
                draft["current"]["state"] = "observe"
            else:
                draft["needs"]["text"] = "你的星盘显示你需要对方说一句能兑现的承诺。"
        else:
            assert requests == ["life_marriage_preview", "life_marriage_preview_repair"]
            assert set(contract["schema"]["properties"]) == {field}
            assert context["correction"]["fields"] == {field: path}
            rejected = json.loads(context["correction"]["draft"])
            assert (rejected["current"] if known else rejected["needs"]["text"]) is None
            draft = {field: {"text": FREE_TEXT["current"]} if known else FREE_TEXT["needs"]}
            if known:
                assert contract["schema"]["properties"][field]["properties"]["state"]["enum"] == list(marriage_report.STATES[:3])
                draft[field].update(state="ready_to_assess", evidence_ids=context["field_sources"]["current"][:1])
        return httpx.Response(200, json={
            "choices": [{"message": {"content": json.dumps(draft, ensure_ascii=False)}, "finish_reason": "stop"}],
        })

    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: client_class(transport=httpx.MockTransport(respond), **kwargs))
    config = replace(settings(postgres_url), fortune_provider="openai",
                     providers={"openai": ProviderConfig("test-key", "https://preview-model.example/v1", "test-model")})
    with TestClient(create_app(config)) as client:
        response = client.post("/api/life-reports", headers=HEADERS, json={
            "report_kind": "marriage",
            "profile": {**PROFILE, "birth_time": PROFILE["birth_time"] if known else None},
            "year": 2026,
        })
        assert response.status_code == 200, response.text
        report = response.json()
        assert report["preview_state"] == "ready", report
        assert requests == ["life_marriage_preview", "life_marriage_preview_repair"]
        assert report["marriage"]["preview"][1]["paragraphs"][0].endswith(FREE_TEXT["needs"])
        assert report["marriage"]["full"] is None


@pytest.mark.parametrize("mixed", [False, True])
def test_thai_marriage_preview_recovers_leaked_field_names(postgres_url, monkeypatch, mixed):
    calls = []
    client_class = httpx.AsyncClient

    def respond(request):
        payload = json.loads(request.content)
        assert payload["response_format"] == {"type": "json_object"}
        context = json.loads(payload["messages"][1]["content"])
        calls.append(context)
        if len(calls) == 1:
            draft = {"language": "th", "reading": "marriage-preview"}
            for key, text in THAI_FREE_TEXT.items():
                sources = context["field_sources"][key]
                draft[key] = {"text": text}
                if isinstance(sources, list):
                    draft[key]["evidence_ids"] = sources[:1]
            draft["current"]["state"] = "ready_to_assess"
            draft["needs"]["text"] = "needs " + THAI_FREE_TEXT["needs"]
            draft["attracts"]["text"] = "**Attracts**： " + THAI_FREE_TEXT["attracts"] + " [evidence_ids]"
            draft["drains"]["text"] = THAI_FREE_TEXT["drains"] + " (drains)"
            draft["attracts"]["evidence_ids"] = context["field_sources"]["attracts"][0]
            draft["drains"]["evidence_ids"] *= 2
            if mixed:
                draft["attracts"]["text"] = "คุณมัก attracts คนที่ฟังเรื่องของคุณจนจบและถามให้เข้าใจ"
                draft["drains"]["text"] = "คนที่รอให้คุณ reschedule ทุกครั้งทำให้คุณเสียเวลา"
        else:
            assert len(calls) == 2 and mixed
            correction = context["correction"]
            assert correction["fields"] == {"1": ["attracts", "text"], "2": ["drains", "text"]}
            assert correction["field_errors"] == [
                {"field": "attracts.text", "rule": "language"},
                {"field": "drains.text", "rule": "language"},
            ]
            retained = json.loads(correction["draft"])
            assert retained["attracts"]["text"] is None and retained["drains"]["text"] is None
            assert retained["attracts"]["evidence_ids"] == calls[0]["field_sources"]["attracts"][0]
            assert "reschedule" not in json.dumps(correction)
            draft = {"1": THAI_FREE_TEXT["attracts"], "2": THAI_FREE_TEXT["drains"]}
        return httpx.Response(200, json={
            "choices": [{"message": {"content": json.dumps(draft, ensure_ascii=False)}, "finish_reason": "stop"}],
        })

    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: client_class(transport=httpx.MockTransport(respond), **kwargs))
    config = replace(settings(postgres_url), fortune_provider="deepseek",
                     providers={"deepseek": ProviderConfig("test-key", "https://preview-model.example/v1", "test-model")})
    with TestClient(create_app(config)) as client:
        response = client.post("/api/life-reports", headers=HEADERS, json={
            "report_kind": "marriage", "profile": {**PROFILE, "language": "th"}, "year": 2026,
        })
        assert response.status_code == 200, response.text
        result = response.json()
        assert result["preview_state"] == "ready"
        assert len(calls) == (2 if mixed else 1)
        sections = result["marriage"]["preview"]
        assert sections[1]["paragraphs"][0].endswith(THAI_FREE_TEXT["needs"])
        assert sections[3]["paragraphs"] == [THAI_FREE_TEXT["attracts"], THAI_FREE_TEXT["drains"]]


def test_paid_marriage_repairs_failed_fields_after_an_incomplete_reply(postgres_url, monkeypatch):
    body = LifeInput.model_validate({"report_kind": "marriage", "profile": PROFILE, "year": 2026})
    chart = thai.marriage_preview_chart(PROFILE, datetime(2026, 11, 19).date())
    chart["marriage_future"] = marriage_report.future_windows(chart)
    bundle = marriage_report.bundle(body, chart, full=True)
    valid = {"language": "zh", "reading": "marriage-full"}
    for key, text in FULL_TEXT.items():
        groups = bundle["required_evidence"].get(key, [])
        valid[key] = {"text": text, "evidence_ids": [group[0] for group in groups] or bundle["allowed_evidence"][key][:1]}

    requests = []
    client_class = httpx.AsyncClient

    def respond(request):
        payload = json.loads(request.content)
        contract = payload["response_format"]["json_schema"]
        requests.append(contract["name"])
        properties = contract["schema"]["properties"]
        if len(requests) == 1:
            citations = properties["other_action"]["properties"]["evidence_ids"]
            assert citations["minItems"] == 3
            assert set(citations["items"]["enum"]) == {"H6", "H2", "H10", "H12"}
            draft = deepcopy(valid)
            draft["other_action"]["evidence_ids"] = ["H10"]
            draft["period_two"]["text"] += "到了2027年再核对。"
            draft["planet_pattern"]["text"] = "水星影响你向对方开口时的表达方式。"
            draft["takeaway"]["text"] = valid["fit"]["text"]
        else:
            context = json.loads(payload["messages"][1]["content"])
            correction = context["correction"]
            paths = ({"takeaway.text": ["takeaway", "text"]} if len(requests) == 4 else {
                "planet_pattern.text": ["planet_pattern", "text"],
                "period_two.text": ["period_two", "text"],
                "other_action.evidence_ids": ["other_action", "evidence_ids"],
            })
            assert set(properties) == set(paths)
            assert correction["fields"] == paths
            retained = json.loads(correction["draft"])
            assert retained["fit"] == valid["fit"]
            assert retained["planet_pattern"]["evidence_ids"] == valid["planet_pattern"]["evidence_ids"]
            assert retained["other_action"]["text"] == valid["other_action"]["text"]
            for section, field in paths.values():
                assert retained[section][field] is None
            draft = {key: valid[section][field] for key, (section, field) in paths.items()}
        return httpx.Response(200, json={"choices": [{"message": {"content": json.dumps(draft, ensure_ascii=False)},
                                                       "finish_reason": "length" if len(requests) == 2 else "stop"}]})

    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: client_class(transport=httpx.MockTransport(respond), **kwargs))
    config = replace(settings(postgres_url), fortune_provider="openai", fortune_fallback_provider="",
                     providers={"openai": ProviderConfig("test-key", "https://marriage-model.example/v1", "test-model")})

    async def generate():
        writer = LifeWriter(Storage(postgres_url), config, asyncio.Semaphore(1), charge=False)
        return await writer.generate(bundle, "marriage-owner", "test-client")

    result = asyncio.run(generate())
    assert result["state"] == "ready", result
    assert requests == ["life_marriage_full", *(["life_marriage_full_repair"] * 3)]
    assert result["story"] == {**valid, "translations": {}}
