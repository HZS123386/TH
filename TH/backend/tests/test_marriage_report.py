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
from backend.app.bazi_reports import InvalidBaziReport
from backend.app.config import ProviderConfig
from backend.app.life_report_content import LifeWriter
from backend.app.main import create_app
from backend.app.thai_readings import copy_for
from backend.tests.test_roxy_astrology import HEADERS, PROFILE, settings


FREE_TEXT = {
    "needs": "你要对方给句准话，愿不愿意认真交往。平时两个人各忙各的，你能接受。",
    "reaction": "对方越含糊，你越容易追着问。问几次还没答复，你就不再主动发消息。",
    "trap": "你容易把对方每天主动找你聊天当成认真的信号。要是对方一次次取消见面，也不给新时间，这段关系就只剩手机上的几条消息。",
    "current": "现阶段先看行动能不能稳定下来。有人把安排定下来并照做，才值得增加投入。",
    "attracts": "你容易吸引想被认真听懂的人，他们愿意和你讲出平时没有机会说的话。",
    "drains": "只在方便时出现的人会消耗你。他们接受你的照顾，却很少为见面腾出时间。",
}
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
            draft["current"]["state"] = "ready_to_assess" if known else "observe"
            if known:
                draft["trap"]["evidence_ids"] = ["P_venus"]
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
        _, style, current, _, _ = (section["paragraphs"] for section in free["marriage"]["preview"])
        evidence = calls[0]["evidence"]
        signs = copy_for("zh")["signs"]
        if known:
            venus = evidence["P_venus"]
            needs_position = f"上升落在{signs[evidence['N0']['sign']]}"
            trap_position = f"金星落在{signs[venus['sign']]}第{venus['house']}宫"
        else:
            sun_signs = evidence["P_sun"]["signs"]
            uncertainty = "可能" if len(sun_signs) > 1 else ""
            needs_position = trap_position = f"太阳{uncertainty}落在" + "或".join(signs[index] for index in sun_signs)
        assert style == [
            f"根据你的星盘，{needs_position}，可以看出{FREE_TEXT['needs']}",
            FREE_TEXT["reaction"],
            f"根据你的星盘，{trap_position}，可以看出{FREE_TEXT['trap']}",
        ]
        recent = evidence[calls[0]["required_evidence"]["current"][0][0]]
        assert len(current) == 2
        assert current[1].startswith(f"从近期行运看，{recent['start']}至{recent['end']}，")
        assert current[1].endswith(f"。{FREE_TEXT['current']}")
        if not known:
            assert "本命第" not in current[1]
        assert len(free["marriage"]["preview"][-1]["paragraphs"]) == 5
        assert free["method"]["name"] == "Thai Suriyayatra"
        assert bool(free["chart"]) == known and free["time_accuracy"]["assumed_local_time"] is None
        assert free["marriage"]["full"] is None
        assert [section["key"] for section in free["marriage"]["preview"]] == list(marriage_report.PREVIEW)
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
        sections = complete["marriage"]["full"]
        assert [section["key"] for section in sections] == list(marriage_report.FULL)
        assert FULL_TEXT["fit"] in sections[1]["paragraphs"]
        assert FULL_TEXT["takeaway"] == sections[-1]["paragraphs"][-1]
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
        assert earlier_style == [f"根据你的星盘，{needs_position}。{opening}", *style[1:]]
        assert earlier["marriage"]["full"] == complete["marriage"]["full"]


def test_preview_retries_only_one_invalid_point(postgres_url, monkeypatch):
    requests = []
    client_class = httpx.AsyncClient

    def respond(request):
        assert str(request.url) == "https://preview-model.example/v1/chat/completions"
        payload = json.loads(request.content)
        contract = payload["response_format"]["json_schema"]
        requests.append(contract["name"])
        context = json.loads(payload["messages"][1]["content"])
        if requests == ["life_marriage_preview"]:
            assert context["field_sources"]["needs"] == "P_sun"
            draft = {
                "language": "zh",
                "reading": "marriage-preview",
                **{key: {"text": value} for key, value in FREE_TEXT.items()},
            }
            draft["needs"]["text"] = "你的星盘显示你需要对方说一句能兑现的承诺。"
            draft["current"].update(state="observe", evidence_ids=context["field_sources"]["current"][:1])
        else:
            assert requests == ["life_marriage_preview", "life_marriage_preview_repair"]
            assert set(contract["schema"]["properties"]) == {"needs"}
            assert context["correction"]["fields"] == {"needs": ["needs"]}
            draft = {"needs": {"text": FREE_TEXT["needs"]}}
        return httpx.Response(200, json={
            "choices": [{"message": {"content": json.dumps(draft, ensure_ascii=False)}, "finish_reason": "stop"}],
        })

    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: client_class(transport=httpx.MockTransport(respond), **kwargs))
    config = replace(settings(postgres_url), fortune_provider="openai",
                     providers={"openai": ProviderConfig("test-key", "https://preview-model.example/v1", "test-model")})
    with TestClient(create_app(config)) as client:
        response = client.post("/api/life-reports", headers=HEADERS, json={
            "report_kind": "marriage",
            "profile": {**PROFILE, "birth_time": None},
            "year": 2026,
        })
        assert response.status_code == 200, response.text
        report = response.json()
        assert report["preview_state"] == "ready", report
        assert requests == ["life_marriage_preview", "life_marriage_preview_repair"]
        assert report["marriage"]["preview"][1]["paragraphs"][0].endswith(FREE_TEXT["needs"])
        assert report["marriage"]["full"] is None
