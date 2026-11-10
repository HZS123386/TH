"""Build the read-only GeoNames city catalogue from cities15000.zip."""
import gzip
import json
import re
import sqlite3
import sys
from pathlib import Path
from zipfile import ZipFile


def build(source: Path, target: Path):
    places = []
    with ZipFile(source) as archive:
        for raw in archive.read("cities15000.txt").decode("utf-8").splitlines():
            columns = raw.split("\t")
            city, name, ascii_name, aliases, latitude, longitude = columns[:6]
            country, population, timezone = columns[8], int(columns[14]), columns[17]
            if not timezone:
                continue
            thai = next((item for item in aliases.split(",") if re.search(r"[\u0e01-\u0e5b]", item)), name)
            places.append((country != "TH", -population, {
                "id": city, "name": ascii_name or name, "name_th": thai, "country": country,
                "latitude": float(latitude), "longitude": float(longitude), "timezone": timezone,
            }))
    places.sort(key=lambda item: item[:2])
    target.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps([item[2] for item in places], ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    target.write_bytes(gzip.compress(data, mtime=0))
    print(f"{len(places)} GeoNames locations")


def build_regions(index: Path, catalog: Path, target: Path):
    with gzip.open(catalog, "rt", encoding="utf-8") as source:
        places = json.load(source)

    with sqlite3.connect(index.resolve().as_uri() + "?mode=ro", uri=True) as db:
        regions = []
        for country, code, payload in db.execute(
            "SELECT country, admin1, payload FROM regions WHERE country IN ('CN', 'TH') ORDER BY country, admin1"
        ):
            row = json.loads(payload)
            regions.append({
                "id": f"{country}.{code}", "country": country, "name": row["nameEnglish"],
                "name_zh": row["nameChinese"], "name_th": row["nameThai"],
            })

        cities = {}
        for place in places:
            if place["country"] not in ("CN", "TH"):
                continue
            match = db.execute(
                "SELECT admin1, name_zh FROM places WHERE id = ? AND country = ?",
                (int(place["id"]), place["country"]),
            ).fetchone()
            if match:
                code, name_zh = match
                cities[place["id"]] = [f"{place['country']}.{code}" if code else "", name_zh or ""]

    data = json.dumps({"regions": regions, "cities": cities}, ensure_ascii=False, separators=(",", ":"))
    target.write_bytes(gzip.compress(data.encode("utf-8"), mtime=0))
    print(f"{len(regions)} regions and {len(cities)} matching cities")


if __name__ == "__main__":
    data_dir = Path(__file__).resolve().parents[1] / "fate" / "data"
    if sys.argv[1] == "--regions":
        build_regions(Path(sys.argv[2]), data_dir / "places.json.gz", data_dir / "place-regions.json.gz")
    else:
        build(Path(sys.argv[1]), data_dir / "places.json.gz")
