"""Public capability registry. Planned modules have no calculation endpoints yet."""

MODULES = [
    {
        "id": "bazi",
        "status": "ready",
        "labels": {"zh": "八字四柱", "en": "Chinese Bazi", "th": "ดวงจีนสี่เสา", "vi": "Bát tự Tứ trụ"},
        "method": "Chinese Four Pillars",
        "calculation_version": "sabai-2",
    },
    {
        "id": "western_astrology",
        "status": "planned",
        "labels": {"zh": "西洋占星", "en": "Western astrology", "th": "โหราศาสตร์ตะวันตก", "vi": "Chiêm tinh phương Tây"},
        "method": None,
        "calculation_version": None,
    },
    {
        "id": "thai_astrology",
        "status": "ready",
        "labels": {"zh": "泰式占星", "en": "Thai astrology", "th": "โหราศาสตร์ไทย", "vi": "Chiêm tinh Thái Lan"},
        "method": "Suriyayatra / whole-sign / weekday-0600",
        "calculation_version": "thai-astrology-0.3.2/wanjai-suriyayatra-1",
    },
    {
        "id": "dreams",
        "status": "planned",
        "labels": {"zh": "梦境探索", "en": "Dream exploration", "th": "สำรวจความฝัน", "vi": "Khám phá giấc mơ"},
        "method": None,
        "calculation_version": None,
    },
]
