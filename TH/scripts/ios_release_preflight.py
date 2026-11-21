"""Read-only checks before signing an APP build; never creates an order or purchase."""

from __future__ import annotations

import ipaddress
import json
import os
import sys
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


def config_url(base: str) -> str:
    try:
        parsed = urlsplit(base)
        host = (parsed.hostname or "").lower()
        parsed.port
    except ValueError as error:
        raise ValueError("invalid_api_address") from error
    if (
        parsed.scheme != "https"
        or not host
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
        or host in {"localhost", "example.com", "example.org"}
        or host.endswith((".localhost", ".local", ".test", ".invalid", ".example"))
    ):
        raise ValueError("public_https_api_required")
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        address = None
    if address is not None and not address.is_global:
        raise ValueError("public_https_api_required")
    return base.rstrip("/") + "/api/config"


def release_blockers(config: object) -> list[str]:
    if not isinstance(config, dict):
        return ["invalid_config_response"]
    capabilities = config.get("app_capabilities")
    if not isinstance(capabilities, dict):
        return ["missing_app_capabilities"]
    blockers = [
        key + "_not_ready"
        for key in ("western_reports", "apple_login", "apple_iap")
        if capabilities.get(key) is not True
    ]
    if capabilities.get("development_full_reports") is not False:
        blockers.append("development_report_preview_not_disabled")
    if config.get("demo_login") is not False or config.get("account_login") is not False:
        blockers.append("development_login_not_disabled")
    return blockers


def main() -> int:
    try:
        url = config_url(os.environ.get("FATE_API_BASE_URL", ""))
        request = Request(url, headers={"Accept": "application/json"})
        with urlopen(request, timeout=20) as response:
            raw = response.read(1_048_577)
        if len(raw) > 1_048_576:
            raise ValueError("config_response_too_large")
        blockers = release_blockers(json.loads(raw))
    except ValueError:
        print("Release check failed: invalid HTTPS API address or config response", file=sys.stderr)
        return 1
    except Exception:
        print("Release check failed: HTTPS API config could not be verified", file=sys.stderr)
        return 1
    if blockers:
        print("Release check failed: " + ", ".join(blockers), file=sys.stderr)
        return 1
    print("Release configuration checks passed; native login and purchase acceptance still required")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
