import gzip
import json
import unicodedata
from pathlib import Path

from pydantic import BaseModel


class Place(BaseModel):
    id: str
    name: str
    name_th: str
    country: str
    latitude: float
    longitude: float
    timezone: str
    region: str = ""
    name_zh: str = ""


def normalize(value: str) -> str:
    return unicodedata.normalize("NFKC", value).casefold().strip()


data_dir = Path(__file__).parent / "data"
with gzip.open(data_dir / "place-regions.json.gz", "rt", encoding="utf-8") as source:
    region_data = json.load(source)

with gzip.open(data_dir / "places.json.gz", "rt", encoding="utf-8") as catalog:
    places = []
    for row in json.load(catalog):
        region, name_zh = region_data["cities"].get(row["id"], ("", ""))
        places.append(Place.model_validate({**row, "region": region, "name_zh": name_zh}))
by_id = {place.id: place for place in places}
search_rows = [
    (place, tuple(normalize(name) for name in (place.name, place.name_th, place.name_zh, place.country)))
    for place in places
]
searchable_regions = {place.region for place in places if place.region}


def regions(country: str):
    return [region for region in region_data["regions"] if region["country"] == country and region["id"] in searchable_regions]


def search(query: str, country: str = "", region: str = "") -> list[Place]:
    q = normalize(query)
    if q == "กรุงเทพฯ":
        q = "กรุงเทพ"
    if not q and not country and not region:
        return [place for place in places if place.country == "TH"][:8]

    matches = []
    for index, (place, names) in enumerate(search_rows):
        if (country and place.country != country) or (region and place.region != region):
            continue
        if any(q in name for name in names):
            matches.append((0 if any(name.startswith(q) for name in names) else 1, index, place))
    matches.sort(key=lambda match: match[:2])
    return [place for _, _, place in matches[:15]]
