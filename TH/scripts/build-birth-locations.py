"""Build the offline birthplace index, including administrative city/district names."""
import argparse
import json
import shutil
import sqlite3
import subprocess
import unicodedata
import zipfile
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ("CN", "TH", "HK", "MO", "TW")
SPECIAL_REGIONS = {"HK": 1819729, "MO": 1821274, "TW": 1668284}


def normalized(value):
    return "".join(char for char in unicodedata.normalize("NFKD", value).lower()
                   if not "\u0300" <= char <= "\u036f" and not char.isspace()
                   and not unicodedata.category(char).startswith(("P", "Z")))


def rows(archive, country):
    with zipfile.ZipFile(archive) as source:
        for line in source.open(f"{country}.txt"):
            yield line.decode("utf-8").rstrip("\r\n").split("\t")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=ROOT / "data/geonames")
    args = parser.parse_args()
    args.source_dir.mkdir(parents=True, exist_ok=True)
    for country in SOURCES:
        for suffix, folder in (("", ""), ("-names", "alternatenames/")):
            archive = args.source_dir / f"{country}{suffix}.zip"
            if not archive.exists():
                with urlopen(f"https://download.geonames.org/export/dump/{folder}{country}.zip", timeout=60) as source, archive.open("wb") as output:
                    shutil.copyfileobj(source, output)
    target = ROOT / "data/birth-locations.sqlite3"
    staging = target.with_suffix(".building.sqlite3")
    if staging.exists():
        raise RuntimeError(f"An unfinished index exists: {staging}")
    db = sqlite3.connect(staging)
    db.executescript("""
        PRAGMA journal_mode=OFF;
        PRAGMA synchronous=OFF;
        PRAGMA cache_size=-131072;
        CREATE TABLE translations(id INTEGER, lang TEXT, name TEXT, rank INTEGER, PRIMARY KEY(id,lang)) WITHOUT ROWID;
        CREATE TABLE places(id INTEGER PRIMARY KEY, country TEXT, admin1 TEXT, admin2 TEXT,
            name_en TEXT, name_zh TEXT, name_th TEXT, latitude REAL, longitude REAL, zone TEXT,
            feature TEXT, population INTEGER, kind TEXT);
        CREATE TABLE names(country TEXT, name TEXT, id INTEGER, PRIMARY KEY(country,name,id)) WITHOUT ROWID;
        CREATE TABLE regions(country TEXT, admin1 TEXT, payload TEXT, PRIMARY KEY(country,admin1)) WITHOUT ROWID;
    """)
    with db:
        for country in SOURCES:
            for row in rows(args.source_dir / f"{country}-names.zip", country):
                lang = row[2]
                if lang not in ("zh", "zh-CN", "zh-Hans", "zh-Hant", "th", "en") or (len(row) > 7 and row[7] == "1"):
                    continue
                rank = (0 if lang in ("zh-CN", "zh-Hans") else 4 if lang == "zh-Hant" else 2) + (0 if row[4] == "1" else 1)
                db.execute("INSERT INTO translations VALUES(?,?,?,?) ON CONFLICT(id,lang) DO UPDATE SET name=excluded.name,rank=excluded.rank WHERE excluded.rank<translations.rank",
                           (int(row[1]), "zh" if lang.startswith("zh") else lang, row[3], rank))
            print(f"Loaded {country} translations", flush=True)
    regions = json.loads((ROOT / "backend/content/birth-regions.json").read_text(encoding="utf-8"))["items"]
    by_id = {row["geonameId"]: row for row in regions}
    region_codes = {}
    for country in ("CN", "TH"):
        for row in rows(args.source_dir / f"{country}.zip", country):
            identifier = int(row[0])
            if country == "CN" and row[7] == "ADM1" and identifier in by_id:
                region_codes[(country, row[10])] = by_id[identifier]
            if country == "TH" and identifier in by_id:
                region_codes[(country, row[10])] = by_id[identifier]
    for source, identifier in SPECIAL_REGIONS.items():
        region_codes[("CN", source)] = by_id[identifier]
    with db:
        db.executemany("INSERT INTO regions VALUES(?,?,?)", [(country, code, json.dumps(value, ensure_ascii=False)) for (country, code), value in region_codes.items()])
    seed_script = "import {searchThaiAstrologyLocations as search} from 'thai-astrology'; console.log(JSON.stringify(['CN','TH'].flatMap(countryCode=>search({countryCode,limit:100}).items)));"
    seeds = {row["geonameId"]: row for row in json.loads(subprocess.check_output(["node", "--input-type=module", "-e", seed_script], cwd=ROOT, encoding="utf-8"))}
    counts = {}
    with db:
        for source in SOURCES:
            country = "CN" if source in SPECIAL_REGIONS else source
            count = 0
            for row in rows(args.source_dir / f"{source}.zip", source):
                administrative = row[7] in ("ADM2", "ADM3", "ADM4", "ADM5") or (source in SPECIAL_REGIONS and row[7] == "ADM1")
                if not administrative and (row[6] != "P" or row[7] in ("PPLH", "PPLQ", "PPLW")):
                    continue
                identifier = int(row[0])
                aliases = list(dict.fromkeys([row[1], row[2], *row[3].split(",")]))
                names = dict(db.execute("SELECT lang,name FROM translations WHERE id=?", (identifier,)))
                han = next((name for name in aliases if name and all("\u3400" <= char <= "\u9fff" or char in "· " for char in name)), "")
                thai = next((name for name in aliases if name and all("\u0e01" <= char <= "\u0e5b" or char == " " for char in name)), "")
                seed = seeds.get(identifier, {})
                name_en = seed.get("nameEnglish") or names.get("en") or row[2] or row[1]
                name_zh, name_th = names.get("zh") or han, seed.get("nameThai") or names.get("th") or thai
                if country == "CN" and row[7] in ("PPLC", "PPLA", "PPLA2") and name_zh and not name_zh.endswith("市"):
                    if name_zh + "市" in aliases:
                        name_zh += "市"
                admin1 = source if source in SPECIAL_REGIONS else row[10]
                region = region_codes.get((country, admin1))
                zone = seed.get("timeZone") or row[17] or (region["timeZone"] if region else "Asia/Shanghai" if country == "CN" else "Asia/Bangkok")
                db.execute("INSERT INTO places VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)", (identifier, country, admin1, row[11], name_en, name_zh, name_th,
                           seed.get("latitude", float(row[4])), seed.get("longitude", float(row[5])), zone, row[7], int(row[14] or 0), seed.get("coordinateKind", "administrative-area" if administrative else "city")))
                search_names = {normalized(name) for name in [*aliases, name_en, name_zh, name_th] if name}
                db.executemany("INSERT OR IGNORE INTO names VALUES(?,?,?)", [(country, name, identifier) for name in search_names if name])
                count += 1
                if count % 100000 == 0:
                    print(f"Indexed {source}: {count:,} places", flush=True)
            counts[country] = counts.get(country, 0) + count
            print(f"Indexed {source}: {count:,} places (complete)", flush=True)
        db.execute("DROP TABLE translations")
        db.execute("CREATE INDEX places_region ON places(country,admin1)")
        db.execute("CREATE TABLE metadata(value TEXT)")
        db.execute("INSERT INTO metadata VALUES(?)", (json.dumps({"source": "GeoNames", "license": "CC BY 4.0", "countries": counts, "extracts": SOURCES, "version": 2}),))
    db.execute("VACUUM")
    assert db.execute("PRAGMA quick_check").fetchone()[0] == "ok"
    db.close()
    staging.replace(target)
    print(json.dumps({"path": str(target), "counts": counts, "bytes": target.stat().st_size}), flush=True)


if __name__ == "__main__":
    main()
