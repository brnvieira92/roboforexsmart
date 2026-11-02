from pathlib import Path
import tempfile
import unittest
from tools.opportunity_report import analyze

class OpportunityReportTests(unittest.TestCase):
    def run_report(self, text):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'history.csv'
            p.write_text(text, encoding='utf-8')
            return analyze(p)

    def test_legacy_double_approval_is_one_intent(self):
        r=self.run_report('now;signal;VENDA EURUSD#\n'
            'now;plan_accepted;plan=EURUSD#/EUR_T01/123 | strategy=EUR_T01 | symbol=EURUSD#\n'
            'now;plan_accepted;plan=EURUSD#/EUR_T01/123 | strategy=EUR_T01 | symbol=EURUSD#\n'
            'now;reject;plan=EURUSD#/EUR_T01/123 | Quote changed\n'
            'now;recheck_attempt;symbol=EURUSD# | bar=123\n'
            'now;reject;plan=EURUSD#/EUR_T01/123 | RR insufficient\n')
        self.assertEqual(r['opportunity_count'],1)
        g=r['by_strategy_symbol']['EUR_T01:EURUSD#']
        self.assertEqual(g['approved_intents'],1)
        self.assertEqual(g['rechecks'],1)
        self.assertEqual(r['first_rejections'],{'Quote changed':1})
        self.assertEqual(r['last_rejections'],{'RR insufficient':1})

    def test_alternative_and_fill_share_parent(self):
        r=self.run_report('now;opportunity_new;opportunity=EURUSD#/EUR_T01/123 | strategy=EUR_T01 | symbol=EURUSD#\n'
            'now;signal;VENDA EURUSD#\n'
            'later;opportunity_alternative;opportunity=EURUSD#/EUR_T01/123 | strategy=EUR_BR01 | symbol=EURUSD#\n'
            'later;plan_accepted;opportunity=EURUSD#/EUR_T01/123 | plan=EURUSD#/EUR_BR01/456 | strategy=EUR_BR01 | symbol=EURUSD#\n'
            'later;order_dispatch;opportunity=EURUSD#/EUR_T01/123 | plan=EURUSD#/EUR_BR01/456 | strategy=EUR_BR01 | symbol=EURUSD#\n'
            'later;order_fill;opportunity=EURUSD#/EUR_T01/123 | plan=EURUSD#/EUR_BR01/456 | symbol=EURUSD#\n')
        self.assertEqual(r['opportunity_count'],1)
        g=r['by_strategy_symbol']['EUR_T01:EURUSD#']
        self.assertEqual(g['alternatives'],1)
        self.assertEqual(g['signals'],1)
        self.assertEqual(g['filled_intents'],1)

    def test_unidentified_remains_explicit(self):
        r=self.run_report('now;signal;VENDA EURUSD#\nnow;reject;no plan available\n')
        self.assertEqual(r['opportunity_count'],1)
        self.assertTrue(next(iter(r['intents'])).startswith('unidentified/'))

    def test_interleaved_rechecks_keep_original_symbol(self):
        r=self.run_report('now;signal;VENDA EURUSD#\n'
            'now;reject;plan=EURUSD#/EUR_T01/123 | no room\n'
            'now;signal;COMPRA USDJPY#\n'
            'now;reject;plan=USDJPY#/JPY_B01/123 | no room\n'
            'later;recheck_attempt;symbol=EURUSD# | bar=123\n')
        self.assertEqual(r['by_strategy_symbol']['EUR_T01:EURUSD#']['rechecks'],1)
        self.assertEqual(r['by_strategy_symbol']['JPY_B01:USDJPY#']['rechecks'],0)
