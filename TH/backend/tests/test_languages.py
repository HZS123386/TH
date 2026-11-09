import json

import pytest
from fastapi.testclient import TestClient

from backend.app.config import Settings
from backend.app.main import create_app
from backend.tests.test_app import PROFILE, login


@pytest.fixture
def client(tmp_path):
    with TestClient(create_app(Settings(database_path=str(tmp_path / "languages.db")))) as client:
        yield client


@pytest.mark.parametrize(
    "locale,expected",
    [
        ("zh-CN", "账号或密码不正确"),
        ("th-TH", "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง"),
        ("vi-VN", "Tên tài khoản hoặc mật khẩu không đúng."),
        ("en-US", "Incorrect username or password."),
    ],
)
def test_auth_errors_follow_selected_language(client, locale, expected):
    response = client.post("/api/auth/login", headers={"Accept-Language": locale}, json={"username": "missing", "password": "wrong-password"})
    assert response.status_code == 401
    assert response.json()["detail"] == expected
    assert response.headers["content-language"] == locale


def test_validation_errors_use_vietnamese_and_never_echo_password(client):
    response = client.post("/api/auth/register", headers={"Accept-Language": "vi-VN"}, json={"username": "valid", "password": "secret"})
    assert response.status_code == 422
    assert response.json()["detail"] == "Mật khẩu cần từ 8 đến 128 ký tự."
    assert "secret" not in response.text


def test_language_preference_preserves_chart_revision_history_and_memories(client):
    headers = login(client)
    saved = client.put("/api/profile", headers=headers, json=PROFILE).json()
    client.post("/api/memories", headers=headers, json={"content": "Keep my notes"})
    client.post("/api/chat", headers=headers, json={"message": "hello"})
    history = client.get("/api/history", headers=headers).json()
    assert client.put("/api/preferences/language", headers=headers, json={"language": "vi"}).json() == {"language": "vi"}
    current = client.get("/api/profile", headers=headers).json()
    assert current["revision"] == saved["revision"]
    assert current["chart"] == saved["chart"]
    assert current["profile"]["language"] == "vi"
    assert client.get("/api/history", headers=headers).json() == history
    assert client.get("/api/memories", headers=headers).json()[0]["content"] == "Keep my notes"
    reply = client.post("/api/chat", headers=headers, json={"message": "Chào bạn"})
    tokens = [json.loads(frame.split("data: ", 1)[1])["text"] for frame in reply.text.split("\n\n") if frame.startswith("event: token\n")]
    assert "Đây là câu trả lời minh họa" in "".join(tokens)


def test_language_preference_is_isolated_and_requires_auth(client):
    assert client.put("/api/preferences/language", json={"language": "vi"}).status_code == 401
    first, other = login(client), login(client)
    client.put("/api/profile", headers=other, json=PROFILE)
    client.put("/api/preferences/language", headers=first, json={"language": "vi"})
    assert client.get("/api/profile", headers=other).json()["profile"]["language"] == "zh"
    assert client.put("/api/preferences/language", headers=first, json={"language": "fr"}).status_code == 422


def test_header_language_controls_current_reply_without_changing_birth_details(client):
    headers = login(client)
    client.put("/api/profile", headers=headers, json=PROFILE)
    response = client.post("/api/chat", headers={**headers, "Accept-Language": "en-US"}, json={"message": "hello"})
    tokens = [json.loads(frame.split("data: ", 1)[1])["text"] for frame in response.text.split("\n\n") if frame.startswith("event: token\n")]
    assert "This is a demo reply" in "".join(tokens)
    assert client.get("/api/profile", headers=headers).json()["revision"] == 1
