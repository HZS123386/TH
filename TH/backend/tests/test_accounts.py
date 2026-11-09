import sqlite3

import pytest
from fastapi.testclient import TestClient

from backend.app.config import Settings
from backend.app.main import create_app
from backend.tests.test_app import PROFILE


@pytest.fixture
def settings(tmp_path):
    return Settings(database_path=str(tmp_path / "accounts.db"))


def auth(client, path, username="nok", password="my secret password"):
    response = client.post(f"/api/auth/{path}", json={"username": username, "password": password})
    assert response.status_code in (200, 201)
    return {"Authorization": f"Bearer {response.json()['token']}"}


def test_new_account_has_no_profile_then_relogin_restores_bound_birth_details(settings):
    with TestClient(create_app(settings)) as client:
        headers = auth(client, "register")
        identity = client.get("/api/auth/me", headers=headers).json()
        assert identity["kind"] == "account"
        assert client.get("/api/profile", headers=headers).json() is None
        client.post("/api/auth/logout", headers=headers)
        headers = auth(client, "login")
        assert client.get("/api/profile", headers=headers).json() is None
        assert client.put("/api/profile", headers=headers, json=PROFILE).status_code == 200
        client.post("/api/auth/logout", headers=headers)
        assert client.get("/api/profile", headers=headers).status_code == 401
    with TestClient(create_app(settings)) as client:
        returning = auth(client, "login", username="NOK")
        assert client.get("/api/auth/me", headers=returning).json()["user_id"] == identity["user_id"]
        saved = client.get("/api/profile", headers=returning).json()
        assert saved["revision"] == 1 and saved["profile"] == PROFILE
        reply = client.post("/api/chat", headers=returning, json={"message": "解读保存的生辰"})
        assert "event: done" in reply.text


def test_accounts_cannot_see_each_others_birth_details(settings):
    with TestClient(create_app(settings)) as client:
        first, other = auth(client, "register"), auth(client, "register", username="other")
        client.put("/api/profile", headers=first, json={**PROFILE, "birth_time": None})
        assert client.get("/api/profile", headers=other).json() is None
        client.post("/api/auth/logout", headers=first)
        returning = auth(client, "login")
        saved = client.get("/api/profile", headers=returning).json()
        assert saved["profile"]["birth_time"] is None
        assert saved["chart"]["pillars"]["hour"] is None


def test_passwords_are_salted_and_wrong_credentials_do_not_create_sessions(settings):
    with TestClient(create_app(settings)) as client:
        auth(client, "register")
        auth(client, "register", username="second")
        with sqlite3.connect(settings.database_path) as db:
            hashes = [row[0] for row in db.execute("SELECT password_hash FROM accounts")]
            session_count = db.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
        assert hashes[0] != hashes[1]
        assert all(value.startswith("scrypt-v1$") and "my secret password" not in value for value in hashes)
        wrong = client.post("/api/auth/login", json={"username": "nok", "password": "wrong password"})
        missing = client.post("/api/auth/login", json={"username": "missing", "password": "wrong password"})
        assert wrong.status_code == missing.status_code == 401
        assert wrong.json() == missing.json()
        with sqlite3.connect(settings.database_path) as db:
            assert db.execute("SELECT COUNT(*) FROM sessions").fetchone()[0] == session_count


def test_legacy_anonymous_profile_can_bind_to_account_without_losing_data(settings):
    with TestClient(create_app(settings)) as client:
        old = client.post("/api/auth/demo").json()
        headers = {"Authorization": f"Bearer {old['token']}"}
        client.put("/api/profile", headers=headers, json=PROFILE)
        bound = client.post("/api/auth/register", headers=headers, json={"username": "nok", "password": "my secret password"}).json()
        assert bound["user_id"] == old["user_id"]
        assert client.get("/api/profile", headers=headers).status_code == 401
        returning = auth(client, "login")
        assert client.get("/api/profile", headers=returning).json()["profile"] == PROFILE


def test_duplicate_account_and_client_supplied_user_id_are_rejected(settings):
    with TestClient(create_app(settings)) as client:
        auth(client, "register")
        assert client.post("/api/auth/register", json={"username": "NOK", "password": "another password"}).status_code == 409
        assert client.post("/api/auth/register", json={"username": "other", "password": "another password", "user_id": "nok"}).status_code == 422
        assert client.post("/api/auth/register", json={"username": "new", "password": "short"}).status_code == 422


def test_production_keeps_local_account_endpoints_closed(settings):
    settings.app_env = "production"
    with TestClient(create_app(settings)) as client:
        for path in ("register", "login"):
            assert client.post(f"/api/auth/{path}", json={"username": "nok", "password": "my secret password"}).status_code == 403
