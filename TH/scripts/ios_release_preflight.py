"""Verify the public App backend before signing an iOS build."""

from __future__ import annotations

import ipaddress
import json
import os
import sys
from urllib.error import HTTPError
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
    blockers = []
    if config.get("service") != "fate-ios-app":
        blockers.append("dedicated_ios_backend_required")
    capabilities = config.get("app_capabilities")
    reading = capabilities.get("thai_reading") if isinstance(capabilities, dict) else None
    if (
        config.get("guest_reading") is not True
        or not isinstance(reading, dict)
        or reading.get("provider") != "deepseek"
        or not reading.get("model")
    ):
        blockers.append("thai_reading_provider_not_ready")
    modules = config.get("modules")
    if not isinstance(modules, list) or not any(
        isinstance(module, dict)
        and module.get("id") == "thai_astrology"
        and module.get("status") == "ready"
        for module in modules
    ):
        blockers.append("thai_astrology_not_ready")
    if config.get("demo_login") is not False or config.get("account_login") is not False:
        blockers.append("development_login_not_disabled")
    return blockers


def thai_reading_route_ready(config_endpoint: str) -> bool:
    request = Request(
        config_endpoint.removesuffix("/config") + "/thai-reading",
        data=b"{}",
        headers={"Accept": "application/json", "Content-Type": "application/json"},
        method="POST",
    )
    # Validation rejects the incomplete request before any model call.
    try:
        with urlopen(request, timeout=20):
            return False
    except HTTPError as error:
        with error:
            if error.code != 422:
                return False
            payload = json.loads(error.read(4096))
            return isinstance(payload, dict) and payload.get("code") == "validation_failed"
    except OSError:
        return False


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
    try:
        route_ready = thai_reading_route_ready(url)
    except (OSError, ValueError):
        route_ready = False
    if not route_ready:
        print("Release check failed: Thai reading endpoint could not be verified", file=sys.stderr)
        return 1
    print("Thai chart and report deployment checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
