import unittest

from ios_release_preflight import config_url, release_blockers


def ready_config():
    return {
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

    def test_valid_release_configuration_passes(self):
        self.assertEqual(release_blockers(ready_config()), [])


if __name__ == "__main__":
    unittest.main()
