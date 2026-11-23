import io
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from ios_release_preflight import config_url, release_blockers, thai_reading_route_ready


def ready_config():
    return {
        "service": "fate-ios-app",
        "guest_reading": True,
        "app_capabilities": {"thai_reading": {"provider": "deepseek", "model": "deepseek-flash"}},
        "demo_login": False,
        "account_login": False,
        "modules": [{"id": "thai_astrology", "status": "ready"}],
    }


class ReleasePreflightTests(unittest.TestCase):
    def test_preserves_an_https_base_path(self):
        self.assertEqual(
            config_url("https://api.fate.co.th/backend/"),
            "https://api.fate.co.th/backend/api/config",
        )

    def test_rejects_local_placeholder_and_credential_urls(self):
        for url in (
            "", "http://api.fate.co.th", "https://127.0.0.1",
            "https://[::1]", "https://10.0.0.5", "https://localhost",
            "https://preview.local", "https://api.invalid",
            "https://example.com", "https://user:secret@api.fate.co.th",
            "https://api.fate.co.th?key=secret", "https://api.fate.co.th#preview",
        ):
            with self.subTest(url=url), self.assertRaises(ValueError):
                config_url(url)

    def test_requires_the_thai_astrology_module_to_be_ready(self):
        for modules in (
            [],
            [{"id": "thai_astrology", "status": "planned"}],
            [{"id": "western_astrology", "status": "ready"}],
        ):
            with self.subTest(modules=modules):
                config = ready_config()
                config["modules"] = modules
                self.assertIn("thai_astrology_not_ready", release_blockers(config))

    def test_missing_or_active_development_flags_fail_closed(self):
        for key in ("demo_login", "account_login"):
            config = ready_config()
            config.pop(key)
            self.assertIn("development_login_not_disabled", release_blockers(config))
            for value in (True, None, "false"):
                config[key] = value
                self.assertIn("development_login_not_disabled", release_blockers(config))

    def test_malformed_configs_do_not_pass(self):
        for config in (None, [], {}, {"modules": [None]}):
            self.assertTrue(release_blockers(config))

    def test_catches_a_shared_backend_or_unavailable_reader(self):
        config = ready_config()
        config.pop("service")
        config["app_capabilities"]["thai_reading"] = None
        self.assertIn("dedicated_ios_backend_required", release_blockers(config))
        self.assertIn("thai_reading_provider_not_ready", release_blockers(config))

    def test_probes_the_report_route_without_generation(self):
        base = config_url("https://api.fate.co.th/app-api")
        for status in (422, 404):
            failure = HTTPError(base, status, "", {}, io.BytesIO(b'{"code":"validation_failed"}'))
            with self.subTest(status=status), patch("ios_release_preflight.urlopen", side_effect=failure) as open_url:
                self.assertEqual(thai_reading_route_ready(base), status == 422)
                request = open_url.call_args.args[0]
                self.assertEqual(request.full_url, "https://api.fate.co.th/app-api/api/thai-reading")
                self.assertEqual(request.method, "POST")
                self.assertEqual(request.data, b"{}")

    def test_valid_release_configuration_passes(self):
        self.assertEqual(release_blockers(ready_config()), [])


if __name__ == "__main__":
    unittest.main()
