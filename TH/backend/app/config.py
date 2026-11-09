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
    bazi_provider: str = "github"
    roxy_per_minute: int = 12
    roxy_per_day: int = 80
    bazi_report_provider: str = "qwen"
    bazi_reports_per_minute: int = 6
    bazi_reports_per_day: int = 80

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
            bazi_provider=os.getenv("BAZI_PROVIDER", "github"),
            roxy_per_minute=max(0, int(os.getenv("ROXY_REQUESTS_PER_MINUTE", "12"))),
            roxy_per_day=max(0, int(os.getenv("ROXY_REQUESTS_PER_DAY", "80"))),
            bazi_report_provider=os.getenv("BAZI_REPORT_PROVIDER", "qwen"),
            bazi_reports_per_minute=max(0, int(os.getenv("BAZI_REPORTS_PER_MINUTE", "6"))),
            bazi_reports_per_day=max(0, int(os.getenv("BAZI_REPORTS_PER_DAY", "80"))),
        )
