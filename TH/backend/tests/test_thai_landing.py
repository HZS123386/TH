from fastapi.testclient import TestClient

from backend.app.config import Settings
from backend.app.main import create_app


def test_landing_mount_serves_build_and_keeps_existing_api(tmp_path):
    landing = tmp_path / "landing"
    assets = landing / "assets"
    assets.mkdir(parents=True)
    (landing / "index.html").write_text("<html>Thai landing</html>", encoding="utf-8")
    (assets / "reading.js").write_text("console.log('landing')", encoding="utf-8")
    (tmp_path / "private.env").write_text("private-marker", encoding="utf-8")
    settings = Settings(database_path=str(tmp_path / "test.db"), thai_landing_dir=str(landing))
    with TestClient(create_app(settings)) as client:
        assert "Thai landing" in client.get("/thai-landing/").text
        assert client.get("/thai-landing/assets/reading.js").status_code == 200
        assert client.get("/health").json()["status"] == "ok"
        assert client.get("/api/config").status_code == 200
        escaped = client.get("/thai-landing/%2e%2e/private.env")
        assert escaped.status_code == 404
        assert "private-marker" not in escaped.text


def test_missing_optional_landing_build_does_not_break_api(tmp_path):
    settings = Settings(database_path=str(tmp_path / "test.db"), thai_landing_dir=str(tmp_path / "not-built"))
    with TestClient(create_app(settings)) as client:
        assert client.get("/health").status_code == 200
