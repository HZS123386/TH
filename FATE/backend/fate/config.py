import os
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Settings:
    database_url: str = field(default_factory=lambda: os.environ.get(
        "FATE_DATABASE_URL", "postgresql+psycopg://fate:fate_local_only@127.0.0.1:25447/fate"
    ))
    roxy_api_key: str = field(default_factory=lambda: os.environ.get("FATE_ROXY_API_KEY", "").strip())
    roxy_base_url: str = field(default_factory=lambda: os.environ.get(
        "FATE_ROXY_BASE_URL", "https://roxyapi.com/api/v2/astrology"
    ).rstrip("/"))
    ip_hash_key: str = field(default_factory=lambda: os.environ.get("FATE_IP_HASH_KEY", ""))
    support_email: str = field(default_factory=lambda: os.environ.get("FATE_SUPPORT_EMAIL", "").strip())

    @property
    def can_calculate(self) -> bool:
        return bool(self.roxy_api_key and len(self.ip_hash_key) >= 32)


settings = Settings()
