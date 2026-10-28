import tempfile
import unittest
from pathlib import Path
from tools.history_report import summarize


class HistoryTests(unittest.TestCase):
    def test_events_and_quoted_details(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'history.csv'
            path.write_text('2026.10.27;signal;"COMPRA EURUSD; alerta"\n2026.10.27;123;Humana entrada\n', encoding='utf-8')
            report = summarize(path)
            self.assertEqual(report['events'], 2)
            self.assertEqual(report['counts']['signal'], 1)
            self.assertEqual(report['recent'][0]['detail'], 'COMPRA EURUSD; alerta')

    def test_corrupt_journal_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'history.csv'
            path.write_text('incomplete\n')
            with self.assertRaises(ValueError):
                summarize(path)


class StrategyMetricsTests(unittest.TestCase):
    def test_strategy_costs_and_duplicate_deals(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'history.csv'
            opening = '2026.10.28;deal_metrics;strategy=EUR_T01|symbol=EURUSD#|position=1|deal=10|entry=0|net=-1|commission=-1|swap=0\n'
            closing = '2026.10.28;deal_metrics;strategy=EUR_T01|symbol=EURUSD#|position=1|deal=11|entry=1|net=8|commission=-1|swap=-1\n'
            path.write_text(opening + closing + closing)
            metric = summarize(path)['deal_metrics']['EUR_T01:EURUSD#']
            self.assertEqual(metric, dict(deals=2, net=7.0, commission=-2.0, swap=-1.0))

    def test_nonfinite_metrics_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'history.csv'
            path.write_text('now;deal_metrics;strategy=LEGACY|symbol=EURUSD#|deal=1|net=nan|commission=0|swap=0\n')
            with self.assertRaises(ValueError):
                summarize(path)
