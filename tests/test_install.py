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
            self.assertEqual((version, count), ('3.00', 5))
            self.assertEqual((backup / 'ForexSmart.mq5').read_text(), 'old user file')
            self.assertEqual(credentials.read_text(), 'local-test-placeholder')
            for relative, content in verified_sources()[1].items():
                self.assertEqual((experts / relative).read_bytes(), content)

    def test_modified_bundle_rejected_before_install(self):
        import shutil
        with tempfile.TemporaryDirectory() as folder:
            bundle = Path(folder) / 'bundle'
            shutil.copytree(BUNDLE, bundle)
            (bundle / 'Include' / 'ForexSmartMLRuntime.mqh').write_text('outdated')
            with self.assertRaises(ValueError):
                verified_sources(bundle)

    def test_wrong_destination_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError):
                install(folder)

    def test_retired_modules_and_executable_are_backed_up(self):
        with tempfile.TemporaryDirectory() as folder:
            data=Path(folder); experts=data/'MQL5'/'Experts'; (experts/'Include').mkdir(parents=True)
            old=experts/'Include'/'ForexSmartResearch.mqh'; old.write_text('legacy')
            compiled=experts/'ForexSmart.ex5'; compiled.write_bytes(b'old executable')
            _,_,backup=install(data)
            self.assertFalse(old.exists()); self.assertFalse(compiled.exists())
            self.assertEqual((backup/'Include'/'ForexSmartResearch.mqh').read_text(),'legacy')
            self.assertEqual((backup/'ForexSmart.ex5').read_bytes(),b'old executable')

    def test_windows_crlf_checkout_installs_verified_sources(self):
        import shutil
        with tempfile.TemporaryDirectory() as folder:
            folder=Path(folder); bundle=folder/'bundle';shutil.copytree(BUNDLE,bundle)
            for relative,content in verified_sources()[1].items():
                (bundle/relative).write_bytes(content.replace(b'\n',b'\r\n'))
            data=folder/'terminal';(data/'MQL5').mkdir(parents=True)
            version,count,_=install(data,bundle)
            self.assertEqual((version,count),('3.00',5))
            for relative,content in verified_sources()[1].items():
                self.assertEqual((data/'MQL5'/'Experts'/relative).read_bytes(),content)

    def test_crlf_does_not_hide_changed_code_or_modify_destination(self):
        import shutil
        with tempfile.TemporaryDirectory() as folder:
            folder=Path(folder);bundle=folder/'bundle';shutil.copytree(BUNDLE,bundle)
            source=bundle/'ForexSmart.mq5'
            source.write_bytes(source.read_bytes().replace(b'AutoTrade=false',b'AutoTrade=true').replace(b'\n',b'\r\n'))
            data=folder/'terminal';experts=data/'MQL5'/'Experts';experts.mkdir(parents=True)
            current=experts/'ForexSmart.ex5';current.write_bytes(b'keep this executable')
            with self.assertRaisesRegex(ValueError,'differs beyond LF/CRLF'):
                install(data,bundle)
            self.assertEqual(current.read_bytes(),b'keep this executable')
            self.assertFalse((data/'ForexSmart-backups').exists())
