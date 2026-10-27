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
