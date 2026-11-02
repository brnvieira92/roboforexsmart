"""Persisted strategy identities must remain bijective across tempo changes."""
from pathlib import Path
import re
import unittest

class PersistedPolicyTests(unittest.TestCase):
    def mappings(self):
        source=(Path(__file__).resolve().parents[1]/'mt5/Include/ForexSmartResearch.mqh').read_text()
        codes=re.findall(r'if\(id=="([^"]+)"\)return (\d+);',source)
        names=re.findall(r'if\(code==(\d+)\)return "([^"]+)";',source)
        return codes,names

    def test_recovery_round_trip_including_patient(self):
        codes,names=self.mappings()
        self.assertEqual(len(codes),len(set(name for name,_ in codes)))
        self.assertEqual(len(codes),len(set(code for _,code in codes)))
        self.assertEqual(dict(codes),{name:code for code,name in names})
        for name in ('EUR_T15','JPY_B15','CHF_R15','GBP_T15','EUR_P15','JPY_P15','GBP_P15','EUR_BR15','JPY_BR15','GBP_BR15'):
            self.assertIn(name,dict(codes))

    def test_existing_position_codes_are_unchanged(self):
        codes,_=self.mappings()
        mapping=dict(codes)
        for name,code in {'EUR_T01':'1','JPY_B01':'2','CHF_R01':'3','GBP_T01':'4','EUR_P01':'11','JPY_P01':'12','GBP_P01':'14','EUR_BR01':'21','JPY_BR01':'22','GBP_BR01':'24'}.items():
            self.assertEqual(mapping[name],code)
