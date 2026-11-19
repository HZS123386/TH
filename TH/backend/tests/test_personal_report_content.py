"""The personal template uses isolated synthetic charts and no external model calls."""
import asyncio
from copy import deepcopy
import json
from pathlib import Path
import re

import httpx
import pytest

from backend.app.astrology import RoxyAstrology
from backend.app.bazi_reports import InvalidBaziReport, report_usage_context
from backend.app.config import ProviderConfig
from backend.app.life_report_content import PERSONAL_LOVE_FIELDS, LifeWriter, personal_writing_progress, writing_progress
from backend.app.life_reports import LifeInput
from backend.app.storage import Storage
from backend.tests.test_roxy_astrology import GOLDEN, PROFILE, settings


def personal_fixture_bundle(*, full=False, known=True, language="zh"):
    profile = {**PROFILE, "language": language, "birth_time": PROFILE["birth_time"] if known else None}
    body = LifeInput.model_validate({"profile": profile, "year": 2026})
    events = [{"date": day, "datetime": day + "T12:00:00Z", "domain": "western", "type": "transit-aspect",
               "body": "Jupiter", "target": target, "aspect": "trine", "orb": 0,
               "significance": 82, "description": "A synthetic, validated transit event."}
              for day, target in zip(("2026-11-23", "2026-12-21", "2027-01-10"), ("Sun", "Mercury", "Venus"))]
    chart = {"provider": "roxy", "domain": "astrology", "time_known": known, "raw": deepcopy(GOLDEN),
             "forecast": {"state": "ready" if known else "time_unknown", "start": "2026-11-16", "end": "2027-02-13", "events": events if known else []}}
    return RoxyAstrology.personal_bundle(body, chart, full=full)


def personal_draft(bundle):
    base = {"language": bundle["language"], "reading": bundle["reading"]}
    sun = bundle["personal_signs"]["sun"]["label"]
    asc = bundle["personal_signs"]["ascendant"]
    if bundle["stage"] == "personal_preview":
        return {**base, "relationship": {
            "text": "感情里越想说清自己的真心，越可能在回应还不明确时先交出信任。被认真听见很珍贵，也容易让你忽略对方有没有用行动回应。",
            "action": "留意总能接住你的情绪，却反复绕开见面安排的人。",
            "evidence_ids": bundle["citation_rules"]["relationship_ids"][:2]}, "free_lines": [
            f"太阳{sun}与上升{asc['label']}，让主动表达与照顾他人感受的倾向相互配合。" if asc else f"太阳{sun}提示主动表达的可能，上升仍需准确出生时间才能确认。",
            "你擅长在回应需要的过程中，连接他人并逐步建立信任。",
            "近期或有被关键人物看见的机会窗口。",
        ], "traits": [
            {"title": "有号召力", "text": "面对意见分散的情况，愿意先提出一个大家都能参与的起点。"},
            {"title": "懂得共情", "text": "留意语气和情绪的变化，常会先听完对方在意的事再作回应。"},
            {"title": "善于连接", "text": "能把不同人的想法梳理清楚，找到彼此愿意配合的交集。"},
        ], "opportunity_action": "准备一个能体现长处的实例，在合适的交流中主动分享。"}
    node_copy = [
        {"theme": "表达与回应", "benefit": "表达意愿与实际行动较易衔接，清楚展现能力或能让合适的人留意你的价值，也为后续了解彼此的想法打开交流空间。",
         "caution": "表达过快时，也给对方留下回应的空间。", "action": "准备一段简短介绍，讲清一项具体长处。"},
        {"theme": "信任与边界", "benefit": "真诚回应与亲和表达有助于建立信任，交流中或能获得更多继续了解的空间，也让彼此更清楚对方愿意提供怎样的支持。",
         "caution": "不必为了获得认可，答应所有的需要。", "action": "写下一个想问清的问题，约一次合适的交流。"},
        {"theme": "连接与取舍", "benefit": "把分散的信息连成清楚的思路，有利于交换资源，也为进一步讨论打开空间，让不同需要之间能够衔接的条件更容易浮现。",
         "caution": "想法铺得太大时，先确认能落实的部分。", "action": "选一个真实需求，找到一项能够衔接的资源。"},
    ]
    theme_ids = {key: ids[:2] for key, ids in bundle["citation_rules"]["themes"].items()}
    if aspect := bundle.get("relationship_preview", {}).get("natal_aspect_id"):
        theme_ids["love"] = [aspect, next(key for key in theme_ids["love"] if key != aspect)]
    return {**base, "talent": {
        "text": "你擅长把自己的想法说清楚，也在意他人的真实感受；通过倾听需要、连接合适的信息与资源，清晰表达与体贴回应能够形成配合。",
        "directions": [
            {"title": "回应需要", "text": "面对需要帮助的人，先问清最在意的问题，再用对方容易理解的方式回应，保留彼此选择的空间。"},
            {"title": "连接资源", "text": "当不同的人各有需要时，先整理哪些条件能够衔接，再确认双方是否愿意继续交流，避免替人答应未确定的安排。"},
            {"title": "传递信息", "text": "把复杂信息讲清楚时，先抓住一个重点，再用贴近日常的例子说明，让对方更容易理解并形成自己的判断。"},
        ]}, "themes": {
            "wealth": {"text": "对资源的安全感更容易来自清楚的使用边界，而不只是拥有多少。面对一项支出时，留意它是满足长期需要，还是为了缓解当下的不安；共同承担费用前，把各自能接受的范围说清楚。",
                       "evidence_ids": theme_ids["wealth"]},
            "love": {"text": "聊到见面时，你既想把期待说清楚，也会体谅对方一时答不上来。听到体贴的话，容易先相信安排会落定，于是提前空出自己的时间，却没有确认彼此是否都愿意为这次见面作出安排。",
                     "question": "“你愿意一起定下次见面的时间吗？”",
                     "continue_when": "对方能提出具体时段，计划有变也主动另约，说明彼此愿意商量和调整，可以再约一次看能否兑现。",
                     "slow_down_when": "说清期待后，若几次都由你催问，对方仍把决定往后推，就照常安排自己的行程，等有明确提议再决定要不要见。",
                     "evidence_ids": theme_ids["love"]},
            "risk": {"text": "当多个要求同时增加时，容易把完成速度当成衡量自己的唯一标准。若开始反复检查已经确认过的细节、却迟迟不愿交出结果，这就是负担过重的信号；先划清责任范围，比不断加码更能恢复稳定。",
                     "evidence_ids": theme_ids["risk"]},
        }, "nodes": [
            {"month": rule["month"], **copy,
             "evidence_ids": [rule["transit_id"], rule["supporting_natal_ids"][0]]}
            for rule, copy in zip(bundle["citation_rules"]["months"], node_copy)]}


def personal_writer(postgres_url, provider):
    config = settings(postgres_url)
    config.fortune_provider = provider
    config.providers.setdefault("openai", ProviderConfig("synthetic-openai-key", "https://openai.example/v1", "test-gpt"))
    return LifeWriter(Storage(config.database_url), config, asyncio.Semaphore(1))


@pytest.mark.parametrize("language", ["th", "en", "vi", "my", "km", "lo", "ms", "id"])
def test_personal_free_localized_sign_names_keep_the_requested_language(postgres_url, language):
    writing = json.loads((Path(__file__).parent / "fixtures/personal-preview.json").read_text(encoding="utf-8"))[language]
    bundle = personal_fixture_bundle(language=language)
    signs = bundle["personal_signs"]
    value = {"language": language, "reading": "personal-preview", **writing}
    value["relationship"]["evidence_ids"] = bundle["citation_rules"]["relationship_ids"][:2]
    value["free_lines"][0] = signs["sun"]["label"] + " / " + signs["ascendant"]["label"] + ": " + value["free_lines"][0]
    writer = personal_writer(postgres_url, "openai")
    assert len(writer.validate(json.dumps(value, ensure_ascii=False), bundle)["free_lines"]) == 3
    assert "language=" + language in writer.prompt(bundle)


@pytest.mark.parametrize("provider", ["openai", "qwen"])
@pytest.mark.parametrize("known", [True, False])
def test_personal_free_three_lines_use_actual_signs_and_no_paid_timing(postgres_url, provider, known):
    writer = personal_writer(postgres_url, provider)
    bundle = personal_fixture_bundle(known=known)
    value = personal_draft(bundle)
    result = writer.validate(json.dumps(value, ensure_ascii=False), bundle)
    assert len(result["free_lines"]) == 3
    assert len(result["traits"]) == 3 and result["opportunity_action"]
    schema = writer.response_format(bundle)["json_schema"]["schema"]
    assert {"relationship", "traits", "opportunity_action"} <= set(schema["required"])
    assert set(schema["$defs"]["PersonalRelationship"]["required"]) == {"text", "action", "evidence_ids"}
    assert len(result["relationship"]["evidence_ids"]) == 2
    assert schema["$defs"]["PersonalTrait"]["required"] == ["title", "text"]
    assert bundle["citation_rules"]["months"] == []
    assert bool(bundle["relationship_aspect_label"]) == known
    assert not any(row["type"] == "transit" for row in bundle["evidence"].values())
    if not known:
        assert bundle["personal_signs"]["ascendant"] is None
        assert "准确出生时间" in result["free_lines"][0]
    # Cache restoration may add an empty translations map in the existing writer pipeline.
    assert writer.validate(json.dumps({**value, "translations": {}}, ensure_ascii=False), bundle) == result
    assert 0 < personal_writing_progress(json.dumps(value, ensure_ascii=False), bundle["stage"]) < 100


@pytest.mark.parametrize("target", ["overview", "trait", "action", "title", "missing_trait", "relationship"])
def test_personal_free_sections_add_new_information(postgres_url, target):
    writer = personal_writer(postgres_url, "openai")
    bundle = personal_fixture_bundle()
    value = personal_draft(bundle)
    if target == "overview":
        signs = bundle["personal_signs"]
        value["free_lines"][0] = f"太阳{signs['sun']['label']}与上升{signs['ascendant']['label']}，" + value["free_lines"][2]
    elif target == "trait":
        value["traits"][1]["text"] = value["traits"][0]["text"].replace("，", "：")
    elif target == "action":
        value["opportunity_action"] = value["free_lines"][2]
    elif target == "title":
        value["traits"][1]["title"] = value["traits"][0]["title"]
    elif target == "relationship":
        value["relationship"]["action"] = value["opportunity_action"]
    else:
        value["traits"].pop()
    with pytest.raises(InvalidBaziReport, match="distinct short titles" if target == "title" else "schema" if target == "missing_trait" else "repeats"):
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)


def test_personal_free_allows_short_shared_keywords_and_progress_includes_details(postgres_url):
    writer = personal_writer(postgres_url, "qwen")
    bundle = personal_fixture_bundle()
    value = personal_draft(bundle)
    value["traits"][0]["text"] = "交流中愿意先提出想法，让大家有个共同的起点。"
    value["traits"][1]["text"] = "交流时留意没说完的顾虑，听完整再作回应。"
    writer.validate(json.dumps(value, ensure_ascii=False), bundle)
    start = personal_writing_progress(json.dumps({"free_lines": value["free_lines"]}, ensure_ascii=False), bundle["stage"])
    end = personal_writing_progress(json.dumps(value, ensure_ascii=False), bundle["stage"])
    assert 0 < start < 50 < end < 100


@pytest.mark.parametrize("change", ["missing", "unrelated_evidence", "duplicate_evidence", "missing_aspect", "outsider", "decision", "partner_feelings", "over_combined_limit"])
def test_free_love_preview_is_required_grounded_and_does_not_judge_third_parties(postgres_url, change):
    writer = personal_writer(postgres_url, "openai")
    bundle = personal_fixture_bundle()
    value = personal_draft(bundle)
    if change == "missing":
        value.pop("relationship")
    elif change == "unrelated_evidence":
        value["relationship"]["evidence_ids"] = ["P_sun", "P_mercury"]
    elif change == "duplicate_evidence":
        value["relationship"]["evidence_ids"] = [bundle["citation_rules"]["relationship_ids"][0]] * 2
    elif change == "missing_aspect":
        value["relationship"]["evidence_ids"] = bundle["citation_rules"]["relationship_ids"][1:]
    elif change == "over_combined_limit":
        value["relationship"]["text"] += "。" * 80
    else:
        value["relationship"]["text"] += {"outsider": "存在搅局的人。", "decision": "必须分手。", "partner_feelings": "对方一定会回心转意。"}[change]
    with pytest.raises(InvalidBaziReport, match="combined prose" if change == "over_combined_limit" else "personal"):
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)


@pytest.mark.parametrize("provider", ["openai", "qwen"])
def test_personal_paid_template_schema_and_exact_month_citations(postgres_url, provider):
    writer = personal_writer(postgres_url, provider)
    bundle = personal_fixture_bundle(full=True)
    value = personal_draft(bundle)
    result = writer.validate(json.dumps(value, ensure_ascii=False), bundle)
    assert len(result["talent"]["directions"]) == len(result["nodes"]) == 3
    assert [row["month"] for row in result["nodes"]] == [row["month"] for row in bundle["citation_rules"]["months"]]
    schema = writer.response_format(bundle)["json_schema"]["schema"]
    for node in (schema, *schema["$defs"].values()):
        if "properties" in node:
            assert set(node["required"]) == set(node["properties"])
            assert node["additionalProperties"] is False
    assert "translations" not in schema["properties"]
    assert "themes" in schema["required"]
    assert set(schema["$defs"]["PersonalThemes"]["required"]) == {"wealth", "love", "risk"}
    assert set(schema["$defs"]["PersonalLove"]["required"]) == {"text", "evidence_ids", *PERSONAL_LOVE_FIELDS}
    assert schema["$defs"]["PersonalLove"]["properties"]["evidence_ids"]["items"]["enum"] == bundle["citation_rules"]["themes"]["love"]
    assert schema["$defs"]["PersonalNode"]["properties"]["month"]["enum"] == ["2026-11", "2026-12", "2027-01"]
    assert 0 < writing_progress(json.dumps(value, ensure_ascii=False), "personal_full") < 100
    prompt = writer.prompt(bundle)
    assert "SIX distinct subjects" in prompt and "previous_points" in prompt
    assert "No specific industries" in prompt and "EXACTLY THREE" in prompt
    assert all(rule["transit_id"] in prompt for rule in bundle["citation_rules"]["months"])
    assert prompt.startswith("You are FATE's dedicated Western astrology report generator.")
    assert "talent.text 50-160" in prompt and "benefit 35-110" in prompt
    assert "NO target total word count" in prompt and "observable result" in prompt
    assert "300-400" not in prompt and "talent.text 45-70" not in prompt
    texts = [result["talent"]["text"], *(part[field] for part in result["talent"]["directions"] for field in ("title", "text")),
             *(part[field] for part in result["nodes"] for field in ("theme", "benefit", "caution", "action"))]
    assert sum(len(re.findall(r"[\u3400-\u9fff]", text)) for text in texts) > 400


@pytest.mark.parametrize("language", ["zh", "en"])
def test_personal_paid_natural_bounds_match_validator_and_provider_schema(postgres_url, language):
    writer = personal_writer(postgres_url, "openai")
    bundle = personal_fixture_bundle(full=True, language=language)
    value = personal_draft(bundle)
    bounds = ({"talent": (50, 160), "direction": (25, 75), "topic": (50, 140), "theme": (4, 14),
               "question": (8, 42), "continue_when": (20, 70), "slow_down_when": (20, 80),
               "benefit": (35, 110), "caution": (10, 35), "action": (12, 45)} if language == "zh" else
              {"talent": (150, 500), "direction": (75, 230), "topic": (150, 440), "theme": (4, 55),
               "question": (20, 155), "continue_when": (60, 240), "slow_down_when": (60, 260),
               "benefit": (105, 340), "caution": (30, 110), "action": (36, 140)})
    if language == "en":
        for part, title in zip(value["talent"]["directions"], ("Useful service", "Resource links", "Clear information")):
            part["title"] = title
    fields = [(value["talent"], "text", "talent")]
    fields += [(part, "text", "direction") for part in value["talent"]["directions"]]
    fields += [(part, "text", "topic") for part in value["themes"].values()]
    fields += [(value["themes"]["love"], field, field) for field in PERSONAL_LOVE_FIELDS]
    fields += [(part, field, field) for part in value["nodes"] for field in ("theme", "benefit", "caution", "action")]
    alphabet = "稳清明宽真静细亮柔暖实简恰诚顺敏和安定善勤谦信" if language == "zh" else "abcdefghijklmnopqrstuvwxyz"
    def sample(index, field, length):
        prefix = ("写下" if language == "zh" else "Write ") if field == "action" else ""
        suffix = "?" if field == "question" else ""
        return prefix + alphabet[index] * (length - len(prefix) - (len(suffix) if language != "zh" else 0)) + suffix
    for endpoint in (0, 1):
        for index, (part, field, key) in enumerate(fields):
            part[field] = sample(index, key, bounds[key][endpoint])
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)
    for index, (part, field, key) in enumerate(fields):
        original = part[field]
        for outside in (bounds[key][0] - 1, bounds[key][1] + 1):
            part[field] = sample(index, key, outside)
            with pytest.raises(InvalidBaziReport, match="personal"):
                writer.validate(json.dumps(value, ensure_ascii=False), bundle)
        part[field] = original
    definitions = writer.response_format(bundle)["json_schema"]["schema"]["$defs"]
    for name, key in (("PersonalTalent", "talent"), ("PersonalDirection", "direction"),
                      ("PersonalTopic", "topic"), ("PersonalLove", "topic")):
        schema = definitions[name]["properties"]["text"]
        assert (schema["minLength"], schema["maxLength"]) == (bounds[key][0], bounds[key][1] + (30 if language == "zh" else 0))
    for key in PERSONAL_LOVE_FIELDS:
        schema = definitions["PersonalLove"]["properties"][key]
        assert (schema["minLength"], schema["maxLength"]) == (bounds[key][0], bounds[key][1] + (18 if language == "zh" else 0))
    for key in ("theme", "benefit", "caution", "action"):
        schema = definitions["PersonalNode"]["properties"][key]
        assert (schema["minLength"], schema["maxLength"]) == (bounds[key][0], bounds[key][1] + (20 if language == "zh" else 0))


@pytest.mark.parametrize("key", ["wealth", "love", "risk"])
def test_personal_full_requires_each_promised_subject_and_its_own_evidence(postgres_url, key):
    bundle = personal_fixture_bundle(full=True)
    writer = personal_writer(postgres_url, "openai")
    value = personal_draft(bundle)
    missing = deepcopy(value)
    del missing["themes"][key]
    with pytest.raises(InvalidBaziReport, match="personal schema"):
        writer.validate(json.dumps(missing, ensure_ascii=False), bundle)
    wrong = deepcopy(value)
    wrong["themes"][key]["evidence_ids"] = [bundle["citation_rules"]["months"][0]["transit_id"], "P_sun"]
    with pytest.raises(InvalidBaziReport, match=f"themes.{key}"):
        writer.validate(json.dumps(wrong, ensure_ascii=False), bundle)


@pytest.mark.parametrize("field", PERSONAL_LOVE_FIELDS)
def test_personal_full_requires_each_relationship_answer(field):
    bundle = personal_fixture_bundle(full=True)
    value = personal_draft(bundle)
    del value["themes"]["love"][field]
    with pytest.raises(InvalidBaziReport, match=rf"personal schema.*themes\.love\.{field}"):
        LifeWriter.validate(json.dumps(value, ensure_ascii=False), bundle)


@pytest.mark.parametrize("paraphrase", [False, True])
def test_personal_full_rejects_repeated_ideas_across_different_subjects(postgres_url, paraphrase):
    bundle = personal_fixture_bundle(full=True)
    writer = personal_writer(postgres_url, "openai")
    value = personal_draft(bundle)
    copied = value["themes"]["wealth"]["text"]
    if paraphrase:
        # Minor wording substitutions remove long verbatim spans without adding a new conclusion.
        copied = "".join("同" if index % 6 == 0 else char for index, char in enumerate(copied))
    value["themes"]["love"]["text"] = copied
    with pytest.raises(InvalidBaziReport, match="repeats themes.wealth"):
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)


def test_personal_full_does_not_copy_the_saved_free_action(postgres_url):
    bundle = personal_fixture_bundle(full=True)
    writer = personal_writer(postgres_url, "openai")
    value = personal_draft(bundle)
    saved = personal_draft(personal_fixture_bundle())["opportunity_action"]
    value["nodes"][0]["action"] = saved
    writer.validate(json.dumps(value, ensure_ascii=False), bundle)
    bundle["previous_points"] = [saved]
    with pytest.raises(InvalidBaziReport, match="repeats free preview"):
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)


@pytest.mark.parametrize("field", ["benefit", "caution", "action"])
def test_personal_paid_months_cannot_repeat_complete_sentences(postgres_url, field):
    writer = personal_writer(postgres_url, "qwen")
    bundle = personal_fixture_bundle(full=True)
    value = personal_draft(bundle)
    value["nodes"][1][field] = value["nodes"][0][field]
    with pytest.raises(InvalidBaziReport, match="repeats"):
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)


@pytest.mark.parametrize("sentences", [2, 3])
def test_personal_benefit_allows_two_connected_sentences_but_not_three(postgres_url, sentences):
    writer = personal_writer(postgres_url, "openai")
    bundle = personal_fixture_bundle(full=True)
    value = personal_draft(bundle)
    ending = "。也为后续了解彼此的想法打开交流空间。" if sentences == 3 else "，也为后续了解彼此的想法打开交流空间。"
    value["nodes"][0]["benefit"] = "表达意愿与实际行动较易衔接。清楚展现能力或能让合适的人留意你的价值" + ending
    if sentences == 2:
        assert writer.validate(json.dumps(value, ensure_ascii=False), bundle)["nodes"][0]["benefit"] == value["nodes"][0]["benefit"]
    else:
        with pytest.raises(InvalidBaziReport, match="at most 2 concise"):
            writer.validate(json.dumps(value, ensure_ascii=False), bundle)


def test_personal_paid_rejects_long_reused_clause_but_accepts_shared_short_words(postgres_url):
    writer = personal_writer(postgres_url, "openai")
    bundle = personal_fixture_bundle(full=True)
    value = personal_draft(bundle)
    value["nodes"][0]["caution"] = "交流过快时，也给对方留下回应的空间。"
    value["nodes"][1]["caution"] = "交流中不必为了获得认可而答应所有需要。"
    writer.validate(json.dumps(value, ensure_ascii=False), bundle)
    shared = "清楚表达自己的想法有助于让对方了解真正需求"
    value["nodes"][0]["benefit"] = shared + "，也为进一步交换信息并确认彼此需求留出空间。"
    value["nodes"][1]["benefit"] = shared + "，还能帮助双方明确彼此能够继续协作的部分。"
    with pytest.raises(InvalidBaziReport, match="repeats"):
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)


@pytest.mark.parametrize("action", [
    "给自己留出更多的时间与空间。",
    "保持耐心并等待合适的回应和机会。",
    "让自己慢慢调整状态并保持开放的心态。",
])
def test_personal_action_needs_an_observable_step_not_generic_patience(postgres_url, action):
    writer = personal_writer(postgres_url, "openai")
    bundle = personal_fixture_bundle(full=True)
    value = personal_draft(bundle)
    value["nodes"][0]["action"] = action
    with pytest.raises(InvalidBaziReport, match="concrete observable action"):
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)


@pytest.mark.parametrize("change", ["wrong_sign", "date_in_free", "past_identity", "occupation", "guarantee", "four_lines"])
def test_personal_free_rejects_fabricated_or_private_claims(postgres_url, change):
    writer = personal_writer(postgres_url, "openai")
    bundle = personal_fixture_bundle()
    value = personal_draft(bundle)
    if change == "wrong_sign":
        value["free_lines"][0] = value["free_lines"][0].replace(bundle["personal_signs"]["sun"]["label"], "双鱼座")
    elif change == "date_in_free":
        value["free_lines"][2] = "十二月你有机会得到理解，并建立新的联系。"
    elif change == "past_identity":
        value["free_lines"][1] = "你曾经受到误解，现在更擅长回应需要并建立信任。"
    elif change == "occupation":
        value["free_lines"][1] = "你适合成为医生，在回应他人的需要时逐步建立信任。"
    elif change == "guarantee":
        value["free_lines"][2] = "你一定会得到关键人物的认可，并开始新的合作。"
    else:
        value["free_lines"].append(value["free_lines"][1])
    expected = "remove specific occupations" if change in ("past_identity", "occupation", "guarantee") else "calculated term" if change == "date_in_free" else None
    with pytest.raises(InvalidBaziReport, match=expected):
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)


def test_unknown_birth_time_cannot_assign_ascendant_traits(postgres_url):
    writer = personal_writer(postgres_url, "openai")
    bundle = personal_fixture_bundle(known=False)
    value = personal_draft(bundle)
    value["free_lines"][0] = "太阳" + bundle["personal_signs"]["sun"]["label"] + "让你主动表达，上升也带来照顾他人感受的倾向。"
    with pytest.raises(InvalidBaziReport, match="Ascendant is unknown"):
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)


@pytest.mark.parametrize("line", [
    "在真实交流中，你的细腻与表达或能被契合的人理解。",
    "近期或有被理解的机会，合适的人也可能愿意继续交流。",
    "近期你的表达或能被关键人物看见，也值得保持清楚。",
])
def test_personal_free_third_line_requires_a_near_term_visibility_opportunity(postgres_url, line):
    writer = personal_writer(postgres_url, "openai")
    bundle = personal_fixture_bundle()
    value = personal_draft(bundle)
    value["free_lines"][2] = line
    with pytest.raises(InvalidBaziReport, match="near-term opportunity"):
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)


@pytest.mark.parametrize("change", ["wrong_month", "wrong_transit", "wrong_natal", "duplicate_month", "missing_node", "specific_job"])
def test_personal_full_rejects_unsupported_node_or_talent_claims(postgres_url, change):
    writer = personal_writer(postgres_url, "qwen")
    bundle = personal_fixture_bundle(full=True)
    value = personal_draft(bundle)
    if change == "wrong_month":
        value["nodes"][0]["month"] = "2030-01"
    elif change == "wrong_transit":
        value["nodes"][0]["evidence_ids"][0] = value["nodes"][1]["evidence_ids"][0]
    elif change == "wrong_natal":
        value["nodes"][0]["evidence_ids"][1] = "P_pluto"
    elif change == "duplicate_month":
        value["nodes"][1]["month"] = value["nodes"][0]["month"]
    elif change == "missing_node":
        value["nodes"].pop()
    else:
        value["talent"]["directions"][0]["title"] = "医生"
    with pytest.raises(InvalidBaziReport):
        writer.validate(json.dumps(value, ensure_ascii=False), bundle)


@pytest.mark.parametrize("primary_unavailable", [False, True])
def test_personal_writer_keeps_provider_fallback_usage_and_cache(postgres_url, monkeypatch, primary_unavailable):
    config = settings(postgres_url)
    config.fortune_provider, config.fortune_fallback_provider = "openai", "qwen"
    config.providers["openai"] = ProviderConfig("synthetic-openai-key", "https://openai.example/v1", "test-gpt")
    store = Storage(config.database_url)
    writer = LifeWriter(store, config, asyncio.Semaphore(2))
    original_client, calls = httpx.AsyncClient, []
    def respond(request):
        assert request.url.host in ("openai.example", "model.example")
        payload = json.loads(request.content)
        bundle = json.loads(payload["messages"][1]["content"])
        calls.append((request.url.host, bundle["stage"]))
        if request.url.host == "openai.example" and primary_unavailable:
            return httpx.Response(401, json={"error": {"message": "private-account-metadata"}})
        return httpx.Response(200, json={"id": "synthetic-personal-model",
            "choices": [{"finish_reason": "stop", "message": {"content": json.dumps(personal_draft(bundle), ensure_ascii=False)}}],
            "usage": {"prompt_tokens": 120, "completion_tokens": 80}})
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: original_client(transport=httpx.MockTransport(respond), **kwargs))
    async def generate():
        results = []
        for full in (False, True):
            bundle = personal_fixture_bundle(full=full)
            token = report_usage_context.set(("synthetic-personal-flow", "full" if full else "preview"))
            try:
                results.append(await writer.generate(bundle, "synthetic-owner", "synthetic-network"))
            finally:
                report_usage_context.reset(token)
        before = len(calls)
        cached = await writer.generate(personal_fixture_bundle(full=True), "synthetic-owner", "synthetic-network")
        assert cached["state"] == "ready" and cached["cached"] is True and len(calls) == before
        return results
    results = asyncio.run(generate())
    assert all(result["state"] == "ready" for result in results)
    assert not any("private-account-metadata" in str(result) for result in results)
    with store.connect() as db:
        rows = db.execute("SELECT provider,phase,stage,validated FROM report_model_usage WHERE report_id=%s ORDER BY id", ("synthetic-personal-flow",)).fetchall()
    ready = [row for row in rows if row["validated"]]
    assert len(ready) == 2
    assert [row["stage"] for row in ready] == ["personal_preview", "personal_full"]
    assert [row["phase"] for row in ready] == ["preview", "full"]
    assert {row["provider"] for row in ready} == {"qwen" if primary_unavailable else "openai"}
    assert len(calls) == (3 if primary_unavailable else 2)
