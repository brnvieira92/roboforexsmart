from pathlib import Path
import tempfile
import unittest
from tools.ml_journal_report import analyze

class MLJournalTests(unittest.TestCase):
    def test_old_signals_are_not_new_ml_signals(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'journal.csv'
            p.write_text('old;signal;COMPRA EURUSD#\n'
                'new;ml_score;strategy=ML_PA_V1 | symbol=EURUSD# | bar=100 | probability=.6\n'
                'new;ml_score;strategy=ML_PA_V1 | symbol=EURUSD# | bar=100 | probability=.4\n'
                'new;ml_session;DISARMED | reason=manual\n')
            result=analyze(p)
            self.assertEqual(result['evaluated_closed_bars'],{'EURUSD#':1})
            self.assertEqual(result['events']['ml_score'],2)
            self.assertNotIn('signal',result['events'])

    def test_only_fully_closed_ml_positions_consolidate(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'journal.csv'
            p.write_text('now;plan_exit;strategy=EUR_T15|position=old|fully_closed=1|cumulative_net=20\n'
                'now;plan_exit;strategy=ML_PA_V1|position=1|fully_closed=0|cumulative_net=1\n'
                'later;plan_exit;strategy=ML_PA_V1|position=1|fully_closed=1|cumulative_net=3|net_R=.8|duration_seconds=900\n')
            stats=analyze(p)['closed_position_statistics']
            self.assertEqual(stats['closed_positions'],1)
            self.assertEqual(stats['net'],'3')
