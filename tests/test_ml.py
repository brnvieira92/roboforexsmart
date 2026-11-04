from dataclasses import replace
import csv
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from tools.forex_ml import Bar,FEATURES,SYMBOLS,features,geometry,simulate,temporal_split,portfolio,statistics,kelly
from tools.prepare_forex_ml import fit_logistic,probabilities,qualification,write_model,train


def past_bars():
    return [Bar(time=100000-i*900,open=1.1+i*.0001,high=1.1002+i*.0001,low=1.09985+i*.0001,close=1.10005+i*.0001,spread=.0001,point=.00001,tick=.00001,contract=100000) for i in range(32)]

class MLPolicyTests(unittest.TestCase):
    def test_book_kelly_arithmetic_and_negative_edge(self):
        self.assertAlmostEqual(kelly(.7,3),.6)
        self.assertLess(kelly(.4,.5),0)
        self.assertEqual(kelly(.7,0),0)

    def test_pure_mql_features_match_python(self):
        compiler=shutil.which('g++')
        if not compiler:self.skipTest('native compiler unavailable; not MQL integration')
        with tempfile.TemporaryDirectory() as folder:
            exe=Path(folder)/'ml'
            source=Path(__file__).parent/'native'/'test_ml.cpp'
            subprocess.run([compiler,'-std=c++17','-Wall','-Wextra','-Werror',str(source),'-o',str(exe)],check=True)
            native=list(map(float,subprocess.check_output([str(exe)],text=True).split()))
        x,a=features(past_bars(),True,.0001)
        score=-.3+sum(j*.01*v for j,v in enumerate(x));p=1/(1+math.exp(-(.9*score+.2)))
        for left,right in zip(native,[a,p,*x]):self.assertAlmostEqual(left,right,places=9)

    def test_no_future_bar_spread_in_features(self):
        past=past_bars()
        future=[Bar(time=100900+i*900,open=1.1002,high=1.1015,low=1.098,close=1.1002,spread=.0001,point=.00001,tick=.00001,contract=100000) for i in range(8)]
        a=simulate('EURUSD#',past,future,True)
        altered=[replace(b,spread=.002) for b in future]
        b=simulate('EURUSD#',past,altered,True)
        self.assertEqual(a['x'],b['x'])
        self.assertTrue(a['both_touched']);self.assertLess(a['net_R'],0)

    def test_chronological_purge_prevents_label_leakage(self):
        records=[dict(entry_time=i*900,exit_time=(i+8)*900) for i in range(1000)]
        training,calibration,test,split=temporal_split(records)
        self.assertLess(max(r['exit_time'] for r in training),split['train_boundary']-7200)
        self.assertLess(max(r['exit_time'] for r in calibration),split['test_boundary']-7200)
        self.assertGreaterEqual(min(r['entry_time'] for r in test),split['test_boundary'])

    def test_portfolio_uses_probability_not_future_profit_and_limits_slots(self):
        rows=[];prob=[]
        for s in SYMBOLS:
            for side,p in [(True,.8),(False,.7)]:
                rows.append(dict(entry_time=100,exit_time=10000,symbol=s,buy=side,net_R=-1 if side else 10));prob.append(p)
        selected=portfolio(rows,prob)
        self.assertEqual(len(selected),2)
        self.assertEqual(len({r['symbol'] for r in selected}),2)
        self.assertTrue(all(r['buy'] for r in selected))

    def test_negative_or_insufficient_evidence_does_not_qualify(self):
        stat=dict(trades=10,profit_factor=.8,net_R=-1,win_lower=.4,payoff=.7)
        ok,reasons,_,_=qualification(stat,stat,{s:stat for s in SYMBOLS})
        self.assertFalse(ok);self.assertGreater(len(reasons),0)
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError):write_model(Path(folder)/'model.csv',{},dict(qualified=False),0)
            self.assertFalse((Path(folder)/'model.csv').exists())

    def test_logistic_training_is_real_fit_not_fixed_weights(self):
        try:import numpy as np
        except ImportError:self.skipTest('numpy optional training dependency unavailable')
        rng=np.random.default_rng(123)
        x=rng.normal(size=(400,FEATURES));y=(x[:,0]+.5*x[:,1]>0).astype(float)
        m=fit_logistic(x,y);m.update(calibration_a=1.,calibration_b=0.)
        pred=probabilities(m,[dict(x=row.tolist()) for row in x])
        self.assertGreater(float(np.mean((pred>.5)==y)),.9)
        self.assertGreater(abs(m['weights'][0]),.1)

    def test_artifact_checksum_and_shape_no_model_shipped(self):
        m=dict(mean=[0.]*FEATURES,scale=[1.]*FEATURES,weights=[.01]*FEATURES,bias=0.,calibration_a=1.,calibration_b=0.)
        # Synthetic serialization fixture only. Never installed in a terminal or committed as a model.
        report=dict(qualified=True,model_id='SYNTHETIC_TEST_ONLY',kelly_win_lower=.7,kelly_payoff_lower=1.2,test=dict(trades=100,profit_factor=1.5,net_R=3.),evaluation_end=1000)
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'model.csv';write_model(path,m,report,0)
            text=path.read_text();payload,checksum=text.rsplit('sha256;',1)
            self.assertEqual(hashlib.sha256(payload.encode()).hexdigest(),checksum.strip())
            self.assertEqual(len(payload.splitlines()),62)
        self.assertFalse((Path(__file__).parents[1]/'mt5'/'ForexSmart-ml-model.csv').exists())

    def test_insufficient_real_data_is_rejected_before_training(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'empty.csv'
            path.write_text('symbol,time,open,high,low,close,spread,point,tick,contract\n')
            with self.assertRaisesRegex(ValueError,'Mínimo6000'):train(path)

    def test_entry_time_exit_and_statistics_are_observations(self):
        s=statistics([dict(exit_time=2,net_R=-1,duration=900,both_touched=True),dict(exit_time=3,net_R=1.25,duration=1800,both_touched=False)])
        self.assertAlmostEqual(s['net_R'],.25);self.assertAlmostEqual(s['profit_factor'],1.25)
        self.assertEqual(s['ambiguous_stop_first'],1)

    def test_trailing_only_after_closed_candle_not_same_bar_hindsight(self):
        past=[Bar(time=100000-i*900,open=1.1,high=1.1004,low=1.0996,close=1.1,spread=.0001,point=.00001,tick=.00001,contract=100000) for i in range(32)]
        first=Bar(time=100900,open=1.1,high=1.10082,low=1.1,close=1.10078,spread=.0001,point=.00001,tick=.00001,contract=100000)
        later=[replace(first,time=101800+i*900,open=1.1007,low=1.1003,close=1.10075) for i in range(7)]
        result=simulate('EURUSD#',past,[first,*later],True)
        self.assertGreater(result['exit_time'],first.time+900)
        self.assertEqual(result['reason'],'HORIZON')

    def test_single_strategy_panel_is_six_inputs(self):
        import re
        source=(Path(__file__).parents[1]/'mt5'/'ForexSmart.mq5').read_text()
        names=re.findall(r'^input \w+ (\w+)=',source,re.MULTILINE)
        self.assertEqual(names,['AutoTrade','RiskPercent','ProfitUSD','DailyLossPercent','CommissionPerLotRoundTurn','TelegramNotifications'])

    def test_cli_failure_writes_report_without_model(self):
        from tools.prepare_forex_ml import main
        with tempfile.TemporaryDirectory() as folder:
            folder=Path(folder);source=folder/'empty.csv';report=folder/'report.json';output=folder/'model.csv'
            source.write_text('symbol,time,open,high,low,close,spread,point,tick,contract\n')
            code=main(['--csv',str(source),'--report',str(report),'--output',str(output)])
            self.assertEqual(code,2);self.assertFalse(output.exists())
            self.assertFalse(json.loads(report.read_text())['qualified'])
