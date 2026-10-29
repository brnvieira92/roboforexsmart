from pathlib import Path
import tempfile
import unittest
from tools.plan_report import evaluate
from tools.history_report import read_events


class PlanAuditTests(unittest.TestCase):
    def test_no_duplicate_money_and_external_separation(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder) / 'journal.csv'
            automatic = 'now;deal_metrics;strategy=EUR_T01|symbol=EURUSD#|position=1|deal=11|entry=1|net=-23.46\n'
            external = 'now;deal_metrics;strategy=EXTERNAL|symbol=GBPUSD#|position=2|deal=12|entry=1|net=5\n'
            p.write_text(automatic + automatic + external + 'now;11;Robô saída -23.46\n')
            r = evaluate(p)
            self.assertEqual(r['automated_deal_net_total'], '-23.46')
            self.assertEqual(r['automated_positions_seen'], 1)
            self.assertEqual(r['v3_confirmed_closed_positions'], 0)

    def test_only_explicit_full_close_is_consolidated(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder) / 'journal.csv'
            p.write_text('now;plan_exit;position=1|fully_closed=0|cumulative_net=5\n'
                         'later;plan_exit;position=1|fully_closed=1|cumulative_net=10\n'
                         'later;plan_exit;position=1|fully_closed=1|cumulative_net=10\n')
            r = evaluate(p)
            self.assertEqual(r['v3_confirmed_closed_positions'], 1)
            self.assertEqual(r['v3_exit_records'][0]['cumulative_net'], '10')

    def test_mt5_unquoted_semicolon_status(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder) / 'journal.csv'
            p.write_text('now;session_status;mask=0; checks continue\n')
            self.assertEqual(read_events(p)[0]['detail'], 'mask=0; checks continue')

    def test_closed_statistics_do_not_claim_equity_drawdown(self):
        from tools.plan_report import closed_statistics
        r = closed_statistics([
            dict(cumulative_net='10', net_R='1', duration_seconds='60'),
            dict(cumulative_net='-5', net_R='-1', duration_seconds='120'),
        ])
        self.assertEqual(r['profit_factor'], '2')
        self.assertEqual(r['mean_net_R'], '0')
        self.assertEqual(r['closed_result_drawdown_currency'], '5')
        self.assertEqual(r['mean_duration_seconds'], '90')
