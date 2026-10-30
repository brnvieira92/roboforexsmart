import json
import tempfile
import unittest
from pathlib import Path
from tools.install_mt5 import BUNDLE, install, verified_sources


class InstallTests(unittest.TestCase):
    def test_complete_bundle_and_backup_preserve_credentials(self):
        with tempfile.TemporaryDirectory() as folder:
            data = Path(folder)
            experts = data / 'MQL5' / 'Experts'
            experts.mkdir(parents=True)
            (experts / 'ForexSmart.mq5').write_text('old user file')
            credentials = data / 'MQL5' / 'Files' / 'ForexSmart-telegram.txt'
            credentials.parent.mkdir()
            credentials.write_text('local-test-placeholder')
            version, count, backup = install(data)
            self.assertEqual((version, count), ('2.12', 9))
            self.assertEqual((backup / 'ForexSmart.mq5').read_text(), 'old user file')
            self.assertEqual(credentials.read_text(), 'local-test-placeholder')
            for relative, content in verified_sources()[1].items():
                self.assertEqual((experts / relative).read_bytes(), content)

    def test_modified_bundle_rejected_before_install(self):
        import shutil
        with tempfile.TemporaryDirectory() as folder:
            bundle = Path(folder) / 'bundle'
            shutil.copytree(BUNDLE, bundle)
            (bundle / 'Include' / 'ForexSmartAccount.mqh').write_text('outdated')
            with self.assertRaises(ValueError):
                verified_sources(bundle)

    def test_wrong_destination_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError):
                install(folder)

    def test_stale_global_handle_names_absent(self):
        import re
        for relative, content in verified_sources()[1].items():
            if relative.name == 'ForexSmartCore.mqh':
                continue
            source = content.decode('utf-8')
            self.assertIsNone(re.search(r'\b(?:fast|slow|atr|paused)\b', source), str(relative))
