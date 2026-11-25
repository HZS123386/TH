import json

import httpx
import pytest
from fastapi.testclient import TestClient

from backend.app.config import ProviderConfig, Settings
from backend.app.main import create_app


CARD_IDS = {
    "world": 21, "fool": 0, "strength": 8, "temperance": 14, "judgement": 20,
}
COPIES = {
    "zh": ("先看看你最在意的条件", "这组牌提醒你先把已经发生的事写下来，再想你想怎样回应。",
           "今天可以先记下一项最重要的需要。", "确认边界",
           "这张牌提醒你为自己的决定保留余地。", "对照你问的选择，先看看哪些条件需要实际确认。"),
    "th": ("ค่อยทบทวนสิ่งที่สำคัญ", "ไพ่ชุดนี้ชวนให้ทบทวนสิ่งที่เกิดขึ้นจริง แล้วดูว่าคุณอยากตอบอย่างไร",
           "ลองจดความต้องการที่สำคัญที่สุดหนึ่งข้อ", "ขอบเขต",
           "ไพ่ใบนี้ชวนให้เผื่อพื้นที่สำหรับการตัดสินใจ", "เทียบทางเลือกในคำถามแล้วดูว่ามีเงื่อนไขใดที่ควรตรวจสอบ"),
}


@pytest.fixture
def tarot_client(postgres_url, monkeypatch):
    cards, prompts = [], []
    behavior = {}
    real_client = httpx.AsyncClient

    def handler(request):
        if request.url.host == "roxyapi.com":
            slug = request.url.path.rsplit("/", 1)[-1]
            cards.append((slug, request.url.params["lang"]))
            assert request.method == "GET" and request.content == b""
            assert request.url.path == f"/api/v2/tarot/cards/{slug}"
            assert request.headers["X-API-Key"] == "roxy-test-key"
            if behavior.get("roxy_down"):
                return httpx.Response(503)
            return httpx.Response(200, json={
                "id": slug, "number": CARD_IDS[slug], "arcana": "major",
                "upright": {"description": f"upright meaning for {slug}", "keywords": ["reflection"]},
                "reversed": {"description": f"reversed meaning for {slug}", "keywords": ["pause"]},
            })
        assert request.url == "https://writer.example/v1/chat/completions"
        payload = json.loads(request.content)
        assert "supplied" in payload["messages"][0]["content"]
        bundle = json.loads(payload["messages"][1]["content"])
        prompts.append(bundle)
        headline, summary, step, keyword, meaning, interpretation = COPIES[bundle["language"]]
        story = {"headline": headline, "summary": summary, "next_step": step, "cards": [
            {"id": card["id"], "reversed": card["reversed"], "keyword": keyword,
             "meaning": meaning, "interpretation": interpretation}
            for card in bundle["cards"]
        ]}
        if behavior.get("wrong_orientation"):
            story["cards"][0]["reversed"] = not story["cards"][0]["reversed"]
        packet = {"choices": [{"finish_reason": "stop", "delta": {"content": json.dumps(story, ensure_ascii=False)}}]}
        return httpx.Response(200, headers={"Content-Type": "text/event-stream"},
                              content=f"data: {json.dumps(packet, ensure_ascii=False)}\n\ndata: [DONE]\n\n")

    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    settings = Settings(database_url=postgres_url, roxy_api_key="roxy-test-key", roxy_enabled=True,
                        providers={"qwen": ProviderConfig(key="writer-test-key", base_url="https://writer.example/v1", model="test")})
    with TestClient(create_app(settings)) as client:
        yield client, cards, prompts, behavior


@pytest.mark.parametrize(("spread", "language", "count"), [
    ("single", "zh", 1), ("relationship", "th", 3), ("decision", "zh", 5),
])
def test_tarot_uses_original_order_orientation_and_question(tarot_client, spread, language, count):
    client, roxy_requests, prompts, _ = tarot_client
    question = {"zh": "我该继续这份工作，还是接受新的机会？",
                "th": "ฉันควรอยู่ที่เดิมหรือเปิดใจรับโอกาสใหม่"}[language]
    choices = [{"id": card_id, "reversed": index % 2 == 0}
               for index, card_id in enumerate(list(CARD_IDS.values())[:count])]
    request = {"question": question, "spread_id": spread, "language": language, "topic": "work", "cards": choices}
    assert client.get("/api/tarot/status").json() == {"enabled": True}
    response = client.post("/api/tarot/readings", json=request)
    assert response.status_code == 200
    assert response.headers["Cache-Control"] == "no-store"
    report = response.json()
    assert report["source"] == "roxy" and report["language"] == language
    assert [{"id": card["id"], "reversed": card["reversed"]} for card in report["cards"]] == choices
    assert report["next_step"] == COPIES[language][2]
    assert len(prompts) == 1 and prompts[0]["question"] == question
    assert [card["meaning"] for card in prompts[0]["cards"]] == [
        f"{'reversed' if choice['reversed'] else 'upright'} meaning for {slug}"
        for choice, slug in zip(choices, CARD_IDS)
    ]
    assert len({card["position"] for card in prompts[0]["cards"]}) == count
    assert set(roxy_requests) == {(slug, "zh-Hans" if language == "zh" else "en") for slug in list(CARD_IDS)[:count]}
    assert client.post("/api/tarot/readings", json=request).json() == report
    assert len(roxy_requests) == count and len(prompts) == 1


def test_tarot_rejects_mismatched_cards_and_upstream_failures(tarot_client):
    client, card_requests, prompts, behavior = tarot_client
    body = {"question": "眼前这件事我可以做什么？", "spread_id": "single", "language": "zh",
            "topic": "general", "cards": [{"id": 0, "reversed": False}]}
    for invalid in (
        {**body, "cards": [{"id": 22, "reversed": False}]},
        {**body, "cards": [{"id": 0, "reversed": "false"}]},
        {**body, "spread_id": "relationship", "cards": body["cards"] * 3},
    ):
        assert client.post("/api/tarot/readings", json=invalid).status_code == 422
    assert not card_requests and not prompts

    behavior["wrong_orientation"] = True
    wrong = client.post("/api/tarot/readings", json=body)
    assert wrong.status_code == 503 and "cards" not in wrong.json()
    behavior.clear()
    behavior["roxy_down"] = True
    down = client.post("/api/tarot/readings", json={**body, "cards": [{"id": 8, "reversed": False}]})
    assert down.status_code == 503 and down.json()["code"] == "roxy_unavailable"
    assert len(prompts) == 1
