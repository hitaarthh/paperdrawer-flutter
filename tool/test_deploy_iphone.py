import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import deploy_iphone


class StagingConfigTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.config_path = Path(directory.name) / ".env.staging.json"
        self.config = {
            "SUPABASE_URL": deploy_iphone.STAGING_SUPABASE_URL,
            "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_test",
            "PAPERDRAWER_WEB_URL": "https://staging.example.com",
        }
        path_patch = patch.object(deploy_iphone, "STAGING_CONFIG", self.config_path)
        path_patch.start()
        self.addCleanup(path_patch.stop)

    def check_config(self):
        self.config_path.write_text(json.dumps(self.config), encoding="utf-8")
        deploy_iphone.check_staging_config()

    @patch.object(deploy_iphone, "urlopen")
    def test_checks_only_staging_supabase(self, urlopen):
        self.check_config()

        urlopen.assert_called_once()
        request = urlopen.call_args.args[0]
        self.assertEqual(request.full_url, f"{deploy_iphone.STAGING_SUPABASE_URL}/auth/v1/settings")
        self.assertEqual(request.get_header("Apikey"), "sb_publishable_test")

    @patch.object(deploy_iphone, "urlopen")
    def test_rejects_another_project_before_network_access(self, urlopen):
        self.config["SUPABASE_URL"] = "https://other-project.supabase.co"

        with self.assertRaisesRegex(RuntimeError, "Staging-PaperDrawer project URL"):
            self.check_config()

        urlopen.assert_not_called()

    @patch.object(deploy_iphone, "urlopen")
    def test_rejects_a_server_key_in_mobile_config(self, urlopen):
        self.config["SUPABASE_PUBLISHABLE_KEY"] = "sb_secret_test"

        with self.assertRaisesRegex(RuntimeError, "staging publishable key"):
            self.check_config()

        urlopen.assert_not_called()

    @patch.object(deploy_iphone, "urlopen")
    def test_rejects_the_live_account_site_for_staging(self, urlopen):
        self.config["PAPERDRAWER_WEB_URL"] = "https://www.paperdrawer.app/"

        with self.assertRaisesRegex(RuntimeError, "staging website's HTTPS origin"):
            self.check_config()

        urlopen.assert_not_called()
