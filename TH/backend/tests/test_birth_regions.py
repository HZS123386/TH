import pytest
from fastapi.testclient import TestClient

from backend.app.config import Settings
from backend.app.main import create_app


@pytest.fixture
def client(tmp_path):
    with TestClient(create_app(Settings(database_path=str(tmp_path / "regions.db")))) as client:
        yield client


@pytest.mark.parametrize(("country", "count"), [("CN", 34), ("TH", 77)])
def test_complete_province_options_have_localized_names_and_representative_coordinates(client, country, count):
    response = client.get("/api/thai-locations", params={"country": country, "level": "province"})
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == len(data["items"]) == count
    assert len({row["id"] for row in data["items"]}) == count
    for row in data["items"]:
        assert row["countryCode"] == country
        assert row["coordinateKind"] == "province-seat"
        assert any("\u4e00" <= char <= "\u9fff" for char in row["nameChinese"])
        assert any("\u0e01" <= char <= "\u0e5b" for char in row["nameThai"])
        assert -90 <= row["latitude"] <= 90
        assert -180 <= row["longitude"] <= 180


@pytest.mark.parametrize(("country", "queries", "identifier"), [
    ("CN", ["四川", "Sìchuān", "มณฑลเสฉวน"], "geonames:1794299"),
    ("CN", ["北京", "Beijing", "ปักกิ่ง"], "geonames:2038349"),
    ("TH", ["清迈", "Chiang Mai", "เชียงใหม่"], "geonames:1153671"),
    ("TH", ["北碧", "Kanchanaburi", "กาญจนบุรี"], "geonames:1153081"),
])
def test_province_search_accepts_chinese_thai_and_latin_names(client, country, queries, identifier):
    for query in queries:
        data = client.get("/api/thai-locations", params={"country": country, "level": "province", "query": query}).json()
        assert identifier in {row["id"] for row in data["items"]}


def test_province_selection_resolves_to_the_same_coordinates_in_real_calculation(client):
    region = client.get("/api/thai-locations", params={"country": "CN", "level": "province", "query": "四川"}).json()["items"][0]
    response = client.post("/api/thai-chart/preview", json={
        "birth_date": "1995-08-17", "birth_time": "09:30", "language": "zh",
        "country_code": "CN", "birthplace": "Sichuan, CN", "location_id": region["id"], "timezone": region["timeZone"],
    })
    assert response.status_code == 200
    chart = response.json()
    assert chart["status"] == "ready"
    assert chart["location"]["nameChinese"] == "四川省"
    assert chart["chart"]["input"]["ascendantReference"]["latitude"] == region["latitude"]
    assert chart["chart"]["input"]["ascendantReference"]["longitude"] == region["longitude"]


def test_province_search_excludes_cities_and_validates_scope(client):
    response = client.get("/api/thai-locations", params={"country": "TH", "level": "province", "query": "Hat Yai"})
    assert response.json() == {"items": [], "total": 0}
    assert client.get("/api/thai-locations", params={"level": "unsupported"}).status_code == 422
    assert client.get("/api/thai-locations", params={"country": "TH"}).json()["total"] == 83


@pytest.mark.parametrize("query", ["河北省，邯郸市", "中国，河北省，邯郸市"])
def test_free_text_birthplace_recognizes_country_province_and_city(client, query):
    response = client.get("/api/thai-locations", params={"country": "", "level": "auto", "query": query})
    assert response.status_code == 200
    place = response.json()["resolved"]
    assert place["id"] == "geonames:1808963"
    assert place["countryCode"] == "CN"
    assert place["labelChinese"] == "中国，河北省，邯郸市"
    chart = client.post("/api/thai-chart/preview", json={
        "birth_date": "1995-08-17", "birth_time": "09:30", "country_code": "CN", "birthplace": "Handan, CN",
        "location_id": place["id"], "timezone": place["timeZone"],
    }).json()
    assert chart["status"] == "ready"
    assert chart["location"]["latitude"] == place["latitude"]


def test_auto_birthplace_search_supports_thailand_and_does_not_guess_ambiguous_cities(client):
    thai = client.get("/api/thai-locations", params={"country": "", "level": "auto", "query": "เชียงใหม่ ประเทศไทย"}).json()
    assert thai["resolved"]["countryCode"] == "TH"
    assert "เชียงใหม่" in thai["resolved"]["labelThai"]
    ambiguous = client.get("/api/thai-locations", params={"country": "", "level": "auto", "query": "朝阳"}).json()
    assert ambiguous["resolved"] is None
    assert len(ambiguous["items"]) > 1
    latin = client.get("/api/thai-locations", params={"country": "", "level": "auto", "query": "Hebei, Handan"}).json()
    assert "geonames:1808963" in {row["id"] for row in latin["items"]}
    assert latin["resolved"] is None  # Several local names share this Latin transcription.


@pytest.mark.parametrize(("country", "province", "query", "identifier"), [
    ("CN", "geonames:1808773", "丛台区", "geonames:6586359"),
    ("TH", "geonames:1153671", "เมืองเชียงใหม่", "geonames:1152000"),
    ("CN", "geonames:1819729", "Kowloon", "geonames:1819609"),
    ("CN", "geonames:1668284", "台北", "geonames:1668341"),
    ("CN", "geonames:1821274", "澳门", "geonames:1821274"),
])
def test_scoped_city_and_district_search_includes_special_regions(client, country, province, query, identifier):
    data = client.get("/api/thai-locations", params={"country": country, "province": province, "level": "locality", "query": query}).json()
    assert identifier in {row["id"] for row in data["items"]}
    assert all(row["countryCode"] == country and row["provinceId"] == province for row in data["items"])
    detail = client.get("/api/thai-locations", params={"country": country, "level": "detail", "query": identifier}).json()["resolved"]
    assert detail["provinceId"] == province
    assert detail["provinceNameChinese"] and detail["provinceNameThai"]


def test_dropdown_browses_with_pagination_and_never_crosses_selected_scope(client):
    params = {"country": "CN", "province": "geonames:1808773", "level": "locality"}
    first = client.get("/api/thai-locations", params=params).json()
    second = client.get("/api/thai-locations", params={**params, "offset": 100}).json()
    assert first["total"] > 200
    assert len(first["items"]) == len(second["items"]) == 100
    assert not {row["id"] for row in first["items"]} & {row["id"] for row in second["items"]}
    assert first["resolved"] is None
    for row in first["items"] + second["items"]:
        assert row["provinceId"] == params["province"] and row["countryCode"] == "CN"
    assert client.get("/api/thai-locations", params={**params, "country": "TH"}).json()["items"] == []
    assert client.get("/api/thai-locations", params={**params, "province": "geonames:1808520", "query": "丛台区"}).json()["items"] == []
    assert client.get("/api/thai-locations", params={**params, "province": "invalid"}).status_code == 422


def test_index_contains_cities_for_all_34_chinese_and_77_thai_provinces():
    import json
    import sqlite3
    from pathlib import Path

    root = Path(__file__).resolve().parents[2]
    with sqlite3.connect(root / "data/birth-locations.sqlite3") as db:
        rows = db.execute("SELECT country,admin1,payload FROM regions").fetchall()
        assert len([row for row in rows if row[0] == "CN"]) == 34
        assert len([row for row in rows if row[0] == "TH"]) == 77
        for country, admin1, payload in rows:
            assert db.execute("SELECT 1 FROM places WHERE country=? AND admin1=? LIMIT 1", (country, admin1)).fetchone(), json.loads(payload)["nameEnglish"]
        assert db.execute("SELECT COUNT(*) FROM places WHERE country='TH' AND feature='ADM2'").fetchone()[0] == 928


def test_selected_district_coordinates_are_used_by_the_real_chart(client):
    place = client.get("/api/thai-locations", params={"country": "CN", "province": "geonames:1808773", "level": "locality", "query": "丛台区"}).json()["resolved"]
    chart = client.post("/api/thai-chart/preview", json={
        "birth_date": "1995-08-17", "birth_time": "09:30", "language": "zh", "country_code": "CN",
        "birthplace": "Congtai Qu, CN", "location_id": place["id"], "timezone": place["timeZone"],
    }).json()
    assert chart["status"] == "ready"
    assert chart["location"]["provinceId"] == "geonames:1808773"
    assert chart["chart"]["input"]["ascendantReference"]["latitude"] == place["latitude"]
    assert chart["chart"]["input"]["ascendantReference"]["longitude"] == place["longitude"]
