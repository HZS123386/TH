"""Translate known factor forms without asking a writer to alter their numbers."""
import re
import json
from functools import lru_cache
from pathlib import Path

ELEMENTS = {
    "zh": ["木", "火", "土", "金", "水"], "en": ["Wood", "Fire", "Earth", "Metal", "Water"],
    "th": ["ไม้", "ไฟ", "ดิน", "ทอง", "น้ำ"], "vi": ["Mộc", "Hỏa", "Thổ", "Kim", "Thủy"],
}
STATES = {
    "zh": ["旺", "相", "休", "囚", "死"], "en": ["prosperous", "supported", "resting", "imprisoned", "dead"],
    "th": ["รุ่งเรือง", "ได้รับแรงหนุน", "พักกำลัง", "ถูกจำกัด", "อ่อนกำลังมาก"], "vi": ["vượng", "tướng", "hưu", "tù", "tử"],
}


@lru_cache(maxsize=1)
def terms():
    return json.loads((Path(__file__).resolve().parents[2] / "src/content/bazi-terms.json").read_text(encoding="utf-8"))


def displayed_evidence(bundle, evidence_ids):
    unique = list(dict.fromkeys(evidence_ids))
    related = next((key for key in unique if key in bundle["topic_evidence"]), None)
    return ([related] + [key for key in unique if key != related])[:2] if related else unique[:2]


def fact_summary(bundle, evidence_ids, language, translations, copy):
    data = terms()
    names = data["labels"][language]
    def stem(value):
        return data["stemNames"][language][data["stems"].index(value)]
    def element(value):
        index = ELEMENTS["zh"].index(value) if value in ELEMENTS["zh"] else ELEMENTS["en"].index(value)
        return ELEMENTS[language][index]
    def pillar(value):
        return stem(value[0]) + ("" if language == "zh" else " ") + data["branchNames"][language][data["branches"].index(value[1])]
    def god(value):
        name = value.get("chinese")
        return data["godNames"][language][data["godNames"]["zh"].index(name)] if name in data["godNames"]["zh"] else names[0]
    result = []
    for key in displayed_evidence(bundle, evidence_ids):
        row = bundle["evidence"][key]
        if key.startswith("P"):
            result.append(copy[row["position"] + "Pillar"] + ": " + pillar(row["pillar"]))
        elif key == "D0":
            result.append(names[0] + ": " + stem(row["chinese"]) + " · " + element(row["element"]))
        elif key == "E0":
            result.append(copy["elements"] + ": " + " / ".join(element(name) + " " + str(count) for name, count in row["visible_element_counts"].items()))
        elif key.startswith("T"):
            labels = data["factLabels"][language]
            main = [labels["stemGods"] + ": " + god(row["tenGod"])] if row["tenGod"]["category"] != "self" else []
            hidden = labels["hiddenGods"] + ": " + " / ".join(dict.fromkeys(god(item["tenGod"]) for item in row["hiddenStems"]))
            result.append(copy[row["position"] + "Pillar"] + ": " + pillar(row["pillar"]) + " · " + " · ".join([*main, hidden]))
        elif key == "S0":
            result.append(copy["strength"] + ": " + data["verdicts"][language][row["verdict"]] + " · " + names[1] + " " + str(row["score"]))
        elif key.startswith("S"):
            index = int(key[1:]) - 1
            result.append(data["baziFactorNames"][language][index] + ": " + str(row["contribution"]) + " · " + translations.get(f"strength.factors.{index}.detail", ""))
        elif key == "A0":
            result.append(str(row["year"]) + " · " + pillar(row["pillar"]) + " · " + names[10] + ": " + god(row["tenGod"]))
        elif key == "L0":
            result.append(names[6] + ": " + str(row["startAge"]))
    return ("；" if language == "zh" else "; ").join(result) + ("。" if language == "zh" else ". ")


def factor_translation(raw, language):
    if language == "en":
        return raw if re.fullmatch(r"[\x20-\x7e]+", raw) else None
    def element(name):
        return ELEMENTS[language][ELEMENTS["en"].index(name)] if name in ELEMENTS["en"] else None
    month = re.fullmatch(r"(Wood|Fire|Earth|Metal|Water) is (\w+) in a (Wood|Fire|Earth|Metal|Water) month", raw)
    if month and month[2] in STATES["en"]:
        day, state, birth_month = element(month[1]), STATES[language][STATES["en"].index(month[2])], element(month[3])
        return {"zh": f"日主五行为{day}，生于{birth_month}月，月令状态为{state}。",
                "th": f"ดิถีธาตุ{day}เกิดในเดือนธาตุ{birth_month} มีสภาวะ{state}",
                "vi": f"Nhật chủ thuộc {day}, sinh tháng {birth_month}, có trạng thái {state}."}[language]
    roots = re.fullmatch(r"(\d+) of (\d+) branches store (Wood|Fire|Earth|Metal|Water)", raw)
    if roots:
        count, total, name = roots[1], roots[2], element(roots[3])
        return {"zh": f"{total}个地支中，有{count}个藏有{name}。",
                "th": f"ในกิ่งดิน {total} ตำแหน่ง มี {count} ตำแหน่งที่มีธาตุ{name}",
                "vi": f"Trong {total} địa chi, có {count} chi tàng {name}."}[language]
    party = re.fullmatch(r"(\d+) of the (\d+) other stems support the day stem, and (\d+) of the (\d+) other branches spend it", raw)
    if party:
        stems, total_stems, branches, total_branches = party.groups()
        return {"zh": f"其余{total_stems}个天干中有{stems}个支持日主；其余{total_branches}个地支中有{branches}个耗泄日主。",
                "th": f"ในก้านฟ้าอื่นอีก {total_stems} ตำแหน่ง มี {stems} ตำแหน่งหนุนดิถี และในกิ่งดินอื่นอีก {total_branches} ตำแหน่ง มี {branches} ตำแหน่งใช้กำลังดิถี",
                "vi": f"Trong {total_stems} thiên can còn lại, có {stems} can trợ nhật chủ; trong {total_branches} địa chi còn lại, có {branches} chi làm hao tiết nhật chủ."}[language]
    return None
