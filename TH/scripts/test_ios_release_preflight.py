import unittest

from ios_release_preflight import config_url, release_blockers


def ready_config():
    return {
        "demo_login": False,
        "account_login": False,
        "app_capabilities": {
            "western_reports": True,
            "apple_login": True,
            "apple_iap": True,
            "development_full_reports": False,
        },
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

    def test_all_required_capabilities_must_be_true_booleans(self):
        for key in ("western_reports", "apple_login", "apple_iap"):
            for value in (False, "true", None):
                config = ready_config()
                config["app_capabilities"][key] = value
                with self.subTest(key=key, value=value):
                    self.assertIn(key + "_not_ready", release_blockers(config))

    def test_missing_or_active_development_flags_fail_closed(self):
        for key in ("demo_login", "account_login"):
            config = ready_config()
            config.pop(key)
            self.assertIn("development_login_not_disabled", release_blockers(config))
        for value in (True, None, "false"):
            config = ready_config()
            config["app_capabilities"]["development_full_reports"] = value
            self.assertIn("development_report_preview_not_disabled", release_blockers(config))

    def test_malformed_configs_do_not_pass(self):
        for config in (None, [], {}, {"app_capabilities": []}):
            self.assertTrue(release_blockers(config))

    def test_valid_release_configuration_passes(self):
        self.assertEqual(release_blockers(ready_config()), [])


if __name__ == "__main__":
    unittest.main()
