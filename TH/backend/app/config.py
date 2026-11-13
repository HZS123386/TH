import os
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv


@dataclass
class ProviderConfig:
    key: str = ""
    base_url: str = ""
    model: str = ""

    @property
    def enabled(self) -> bool:
        return bool(self.key and self.base_url.startswith("https://") and self.model)


@dataclass
class Settings:
    database_path: str = "data/sabai.db"
    app_env: str = "development"
    thai_landing_dir: str = ""
    session_hours: int = 168
    default_provider: str = "mock"
    providers: dict[str, ProviderConfig] = field(default_factory=dict)
    embeddings: ProviderConfig = field(default_factory=ProviderConfig)
    chat_per_minute: int = 8
    chat_per_day: int = 200
    fortune_provider: str = "qwen"
    fortune_per_minute: int = 3
    fortune_per_day: int = 12
    fortune_network_per_day: int = 120
    roxy_api_key: str = field(default="", repr=False)
    roxy_enabled: bool = False
    life_astrology_provider: str = "thai"
    bazi_provider: str = "github"
    roxy_per_minute: int = 12
    roxy_per_day: int = 80
    bazi_report_provider: str = "qwen"
    bazi_reports_per_minute: int = 6
    bazi_reports_per_day: int = 80
    payso_test_merchant_id: str = ""
    payso_test_api_key: str = field(default="", repr=False)
    payso_test_secret_key: str = field(default="", repr=False)
    sunlands_order_only: bool = False
    sunlands_base_url: str = "https://api-prod.sunlands.com"
    sunlands_app_key: str = "sunlands_fb_fate"
    sunlands_app_secret: str = field(default="", repr=False)
    sunlands_channel_code: str | None = None
    sunlands_item_no: str = "193261112000101"
    sunlands_product_no: str = "1932611120001"
    sunlands_item_title: str = "测试产品包"
    sunlands_province_id: str = ""
    sunlands_merchant_notify_uri: str = ""
    support_email: str = ""

    @classmethod
    def from_env(cls):
        load_dotenv()
        defaults = {"openai": "https://api.openai.com/v1", "deepseek": "https://api.deepseek.com", "qwen": "", "kimi": "https://api.moonshot.cn/v1"}
        return cls(
            database_path=os.getenv("DATABASE_PATH", "data/sabai.db"),
            app_env=os.getenv("APP_ENV", "development"),
            thai_landing_dir=os.getenv("THAI_LANDING_DIR", str(Path(__file__).resolve().parents[3] / "western-astrology-h5 4" / "site")),
            session_hours=int(os.getenv("SESSION_HOURS", "168")),
            default_provider=os.getenv("DEFAULT_PROVIDER", "mock"),
            providers={
                name: ProviderConfig(
                    os.getenv(f"{name.upper()}_API_KEY", ""), os.getenv(f"{name.upper()}_BASE_URL", default), os.getenv(f"{name.upper()}_MODEL", "")
                )
                for name, default in defaults.items()
            },
            embeddings=ProviderConfig(os.getenv("EMBEDDING_API_KEY", ""), os.getenv("EMBEDDING_BASE_URL", ""), os.getenv("EMBEDDING_MODEL", "")),
            chat_per_minute=max(0, int(os.getenv("CHAT_TURNS_PER_MINUTE", "8"))),
            chat_per_day=max(0, int(os.getenv("CHAT_TURNS_PER_DAY", "200"))),
            fortune_provider=os.getenv("FORTUNE_PROVIDER", "qwen"),
            fortune_per_minute=max(0, int(os.getenv("FORTUNE_REPORTS_PER_MINUTE", "3"))),
            fortune_per_day=max(0, int(os.getenv("FORTUNE_REPORTS_PER_DAY", "12"))),
            fortune_network_per_day=max(0, int(os.getenv("FORTUNE_NETWORK_REPORTS_PER_DAY", "120"))),
            roxy_api_key=os.getenv("ROXY_API_KEY", ""),
            roxy_enabled=os.getenv("ROXY_ENABLED", "false").lower() == "true",
            life_astrology_provider=os.getenv("LIFE_ASTROLOGY_PROVIDER", "thai").lower(),
            bazi_provider=os.getenv("BAZI_PROVIDER", "github"),
            roxy_per_minute=max(0, int(os.getenv("ROXY_REQUESTS_PER_MINUTE", "12"))),
            roxy_per_day=max(0, int(os.getenv("ROXY_REQUESTS_PER_DAY", "80"))),
            bazi_report_provider=os.getenv("BAZI_REPORT_PROVIDER", "qwen"),
            bazi_reports_per_minute=max(0, int(os.getenv("BAZI_REPORTS_PER_MINUTE", "6"))),
            bazi_reports_per_day=max(0, int(os.getenv("BAZI_REPORTS_PER_DAY", "80"))),
            payso_test_merchant_id=os.getenv("PAYSO_TEST_MERCHANT_ID", ""),
            payso_test_api_key=os.getenv("PAYSO_TEST_API_KEY", ""),
            payso_test_secret_key=os.getenv("PAYSO_TEST_SECRET_KEY", ""),
            sunlands_order_only=os.getenv("SUNLANDS_ORDER_ONLY", "false").lower() == "true",
            sunlands_base_url=os.getenv("SUNLANDS_BASE_URL", "https://api-prod.sunlands.com"),
            sunlands_app_key=os.getenv("SUNLANDS_APP_KEY", "sunlands_fb_fate"),
            sunlands_app_secret=os.getenv("SUNLANDS_APP_SECRET", ""),
            sunlands_channel_code=os.getenv("SUNLANDS_CHANNEL_CODE"),
            sunlands_item_no=os.getenv("SUNLANDS_ITEM_NO", "193261112000101"),
            sunlands_product_no=os.getenv("SUNLANDS_PRODUCT_NO", "1932611120001"),
            sunlands_item_title=os.getenv("SUNLANDS_ITEM_TITLE", "测试产品包"),
            sunlands_province_id=os.getenv("SUNLANDS_PROVINCE_ID", ""),
            sunlands_merchant_notify_uri=os.getenv("SUNLANDS_MERCHANT_NOTIFY_URI", ""),
            support_email=os.getenv("FATE_SUPPORT_EMAIL", ""),
        )
