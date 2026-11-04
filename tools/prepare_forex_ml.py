"""Export closed MT5 bars (read only), train ML_PA_V1 and install only a qualified model.
No order_send/login/password calls. On Windows: py tools/prepare_forex_ml.py
"""
import argparse
from collections import Counter
import csv
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys
try:
    from .forex_ml import FEATURES,POLICY,SYMBOLS,load_bars,samples,temporal_split,portfolio,statistics,kelly
except ImportError:
    from forex_ml import FEATURES,POLICY,SYMBOLS,load_bars,samples,temporal_split,portfolio,statistics,kelly


def fit_subset(records,maximum=50000,seed=2026):
    # Sampling is confined to the already purged TRAIN block. Never split time randomly.
    # A fixed stride can alias the buy/sell or symbol ordering (stride2 selected one side).
    import random
    if maximum<1:raise ValueError('Invalid fit sample limit')
    if len(records)<=maximum:return list(records)
    indices=sorted(random.Random(seed).sample(range(len(records)),maximum))
    return [records[index] for index in indices]


def fit_logistic(x,y,epochs=200):
    import numpy as np
    x=np.asarray(x,dtype=float);y=np.asarray(y,dtype=float)
    if len(x)<20 or len(set(y))<2:raise ValueError('Treino precisa das duas classes e dados suficientes')
    mean=x.mean(axis=0);scale=x.std(axis=0);scale=np.where(scale<1e-8,1,scale);z=(x-mean)/scale
    w=np.zeros(x.shape[1]);bias=math.log((float(y.mean())+1e-4)/(1-float(y.mean())+1e-4))
    for _ in range(epochs):
        score=np.clip(z@w+bias,-30,30);error=1/(1+np.exp(-score))-y
        w-=.08*(z.T@error/len(y)+.002*w);bias-=.08*float(error.mean())
    return dict(mean=mean.tolist(),scale=scale.tolist(),weights=w.tolist(),bias=bias)


def scores(model,records):
    import numpy as np
    x=np.asarray([r['x'] for r in records],dtype=float)
    return ((x-np.asarray(model['mean']))/np.asarray(model['scale']))@np.asarray(model['weights'])+model['bias']


def calibrate(score,y):
    import numpy as np
    score=np.asarray(score);y=np.asarray(y);a,b=1.,0.
    for _ in range(300):
        p=1/(1+np.exp(-np.clip(a*score+b,-30,30)));error=p-y
        a=max(.01,min(10,a-.05*float((error*score).mean())));b=max(-10,min(10,b-.05*float(error.mean())))
    return a,b


def probabilities(model,records):
    import numpy as np
    score=scores(model,records)
    return 1/(1+np.exp(-np.clip(model['calibration_a']*score+model['calibration_b'],-30,30)))


def qualification(base,stress,by_pair,calibration=None):
    reasons=[]
    for label,s in (('teste',base),('stress_spread_1.5',stress)):
        if s['trades']<100:reasons.append(label+': menos de100 operações simuladas na carteira')
        if s['trades']==0:
            reasons.append(label+': sem operações avaliadas; desempenho indisponível')
        else:
            if s['profit_factor'] is None or s['profit_factor']<1.05:reasons.append(label+': profit factor abaixo de1.05')
            if s['net_R']<=0:reasons.append(label+': expectativa líquida não positiva')
    for symbol,stats in by_pair.items():
        if stats['trades']==0:reasons.append(symbol+': sem operações avaliadas')
        elif stats['trades']<20 or stats['net_R']<=0:reasons.append(symbol+': evidência insuficiente/negativa no teste')
    g=min(base['win_lower'],stress['win_lower']);v=.9*min(base['payoff'],stress['payoff'])
    if calibration is not None:
        g=min(g,calibration['win_lower']);v=.9*calibration['payoff']
        if calibration['trades']<100:reasons.append('calibração: menos de100 trades')
        if base['trades']>0 and stress['trades']>0 and min(base['payoff'],stress['payoff'])<v:reasons.append('payoff do teste não sustenta a estimativa fixada na calibração')
    if kelly(g,v)<=0:reasons.append('Kelly conservador não positivo')
    return not reasons,reasons,g,v


def selection_diagnostics(records,p,win_lower,payoff_lower):
    import numpy as np
    values=np.asarray(p,dtype=float)
    score=sum(float(value)>=.55 for value in values)
    economic=sum(float(value)>=.55 and ('win_per_lot' not in r or value*r['win_per_lot']-(1-value)*r['initial_loss']>0) for r,value in zip(records,values))
    eligible=sum(float(value)>=.55 and kelly(min(float(value),win_lower),payoff_lower)>0 and ('win_per_lot' not in r or value*r['win_per_lot']-(1-value)*r['initial_loss']>0) for r,value in zip(records,values))
    return dict(directional_records=len(records),score_at_least_055=int(score),score_and_positive_economics=int(economic),
        score_economics_and_positive_kelly=int(eligible),
        probability_min=float(values.min()) if len(values) else None,
        probability_median=float(np.median(values)) if len(values) else None,
        probability_max=float(values.max()) if len(values) else None)


def assess_test(records,p,win_lower,payoff_lower):
    operational=portfolio(records,p,win_lower=win_lower,payoff_lower=payoff_lower)
    diagnostic=portfolio(records,p)
    return operational,dict(
        selection=selection_diagnostics(records,p,win_lower,payoff_lower),
        operational_status='BLOCKED_BY_CALIBRATION_KELLY' if kelly(win_lower,payoff_lower)<=0 else ('NO_ELIGIBLE_TRADES' if not operational else 'EVALUATED'),
        diagnostic_without_kelly=statistics(diagnostic),
        diagnostic_by_pair={symbol:statistics([r for r in diagnostic if r['symbol']==symbol]) for symbol in SYMBOLS},
        warning='Diagnostic simulation only: threshold .55, costs and portfolio limits retained; Kelly gate omitted solely to measure signal behavior. Never used for qualification, model sizing or installation.')


def write_model(path,model,report,commission):
    if not report['qualified']:raise ValueError('Modelo não qualificado não pode ser instalado')
    rows=dict(schema='1',policy=str(POLICY),feature_count=str(FEATURES),timeframe='15',qualification='QUALIFIED',currency='USD',
        model_id=report['model_id'],bias=format(model['bias'],'.17g'),calibration_a=format(model['calibration_a'],'.17g'),
        calibration_b=format(model['calibration_b'],'.17g'),threshold='.55',win_lower=format(report['kelly_win_lower'],'.17g'),
        payoff_lower=format(report['kelly_payoff_lower'],'.17g'),commission=format(commission,'.17g'),slippage_points='2',
        test_trades=str(report['test']['trades']),test_profit_factor=format(report['test']['profit_factor'],'.17g'),
        test_net_R=format(report['test']['net_R'],'.17g'),evaluation_end=str(report['evaluation_end']))
    for i,symbol in enumerate(SYMBOLS):rows['symbol'+str(i)]=symbol
    for i in range(FEATURES):
        rows['mean'+str(i)]=format(model['mean'][i],'.17g');rows['scale'+str(i)]=format(model['scale'][i],'.17g');rows['weight'+str(i)]=format(model['weights'][i],'.17g')
    assert len(rows)==62
    payload=''.join(k+';'+v+'\n' for k,v in rows.items());checksum=hashlib.sha256(payload.encode()).hexdigest()
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    temp=path.with_suffix(path.suffix+'.tmp');temp.write_text(payload+'sha256;'+checksum+'\n',encoding='utf-8',newline='\n');temp.replace(path)


def export_mt5(path,bars,terminal_path=None):
    try:import MetaTrader5 as mt5
    except ImportError:raise ValueError('Instale: py -m pip install -r requirements-ml-windows.txt')
    if not (mt5.initialize(terminal_path) if terminal_path else mt5.initialize()):raise ValueError('Abra o MT5 e conecte a conta antes de exportar')
    try:
        account=mt5.account_info();terminal=mt5.terminal_info()
        if account is None or terminal is None or account.currency!='USD':raise ValueError('É necessária uma conta USD conectada')
        path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
        with path.open('w',encoding='utf-8',newline='') as f:
            writer=csv.writer(f);writer.writerow(('symbol','time','open','high','low','close','spread','point','tick','contract'))
            for symbol in SYMBOLS:
                if not mt5.symbol_select(symbol,True):raise ValueError('Símbolo indisponível: '+symbol)
                spec=mt5.symbol_info(symbol);rates=mt5.copy_rates_from_pos(symbol,mt5.TIMEFRAME_M15,1,bars)
                if spec is None or rates is None:raise ValueError('Histórico indisponível: '+symbol)
                for row in rates:
                    writer.writerow((symbol,int(row['time']),float(row['open']),float(row['high']),float(row['low']),float(row['close']),int(row['spread'])*spec.point,spec.point,spec.trade_tick_size,spec.trade_contract_size))
        print('Terminal MT5 usado:',terminal.name)
        print('Pasta de dados:',terminal.data_path)
        return Path(terminal.data_path)/'MQL5'/'Files'
    finally:mt5.shutdown()


def train(path,commission=0):
    import numpy as np
    data=load_bars(path);counts={k:len(v) for k,v in data.items()}
    if any(n<6000 for n in counts.values()):raise ValueError('Mínimo6000 velas M15 fechadas por par; disponível: '+str(counts))
    records=samples(data,commission);train,calibration,test,boundaries=temporal_split(records)
    if min(len(train),len(calibration),len(test))<500:raise ValueError('Blocos cronológicos insuficientes após purga')
    fit=fit_subset(train)
    model=fit_logistic([r['x'] for r in fit],[r['y'] for r in fit])
    model['calibration_a'],model['calibration_b']=calibrate(scores(model,calibration),[r['y'] for r in calibration])
    calibration_stats=statistics(portfolio(calibration,probabilities(model,calibration)))
    cal_g,cal_v=calibration_stats['win_lower'],.9*calibration_stats['payoff']
    p=probabilities(model,test);trades,test_diagnostics=assess_test(test,p,cal_g,cal_v);stats=statistics(trades)
    stress_records=samples(data,commission,1.5);stress_test=[r for r in stress_records if r['entry_time']>=boundaries['test_boundary']]
    stress_p=probabilities(model,stress_test)
    stress_trades,stress_diagnostics=assess_test(stress_test,stress_p,cal_g,cal_v);stress_stats=statistics(stress_trades)
    by_pair={s:statistics([r for r in trades if r['symbol']==s]) for s in SYMBOLS}
    qualified,reasons,g,v=qualification(stats,stress_stats,by_pair,calibration_stats)
    report=dict(qualified=qualified,reasons=reasons,model_id=hashlib.sha256(json.dumps(model,sort_keys=True).encode()).hexdigest()[:16],
        policy=POLICY,bars=counts,split=boundaries,fit_samples=len(fit),
        fit_selection=dict(method='seeded_random_within_train_only',seed=2026,maximum=50000,by_symbol_and_side=dict(Counter(r['symbol']+(' BUY' if r['buy'] else ' SELL') for r in fit))),
        class_balance=dict(fit_win_rate=sum(r['y'] for r in fit)/len(fit),calibration_win_rate=sum(r['y'] for r in calibration)/len(calibration),test_win_rate=sum(r['y'] for r in test)/len(test)),
        constant_training_baseline_brier=float(np.mean((sum(r['y'] for r in fit)/len(fit)-np.asarray([r['y'] for r in test]))**2)),
        calibration_samples=len(calibration),test_samples=len(test),
        test=stats,calibration=calibration_stats,stress_spread_1_5=stress_stats,by_pair=by_pair,kelly_win_lower=g,kelly_payoff_lower=v,
        calibration_kelly=dict(win_lower=cal_g,payoff_lower=cal_v,raw_fraction=kelly(cal_g,cal_v),break_even_win_rate=1/(1+cal_v) if cal_v>0 else None,positive=kelly(cal_g,cal_v)>0),
        diagnostics=dict(test=test_diagnostics,stress_spread_1_5=stress_diagnostics),
        kelly_full=max(0,kelly(g,v)),kelly_fraction=.25,evaluation_end=max(r['exit_time'] for r in test),
        brier=float(np.mean((p-np.asarray([r['y'] for r in test]))**2)),
        test_log_loss=float(-np.mean(np.asarray([r['y'] for r in test])*np.log(np.clip(p,1e-9,1-1e-9))+(1-np.asarray([r['y'] for r in test]))*np.log(np.clip(1-p,1e-9,1-1e-9)))),
        limitations=['OHLC with conservative stop-first and estimated historical spread; not tick-exact.',
            'Portfolio test limits2 positions and1 per pair, normalized R; no broker margin, USD sizing, minimum-lot or swap simulation.',
            'Model selected/qualified on final holdout; forward demo is still required and profitability is not guaranteed.',
            'Kelly uses conservative empirical holdout estimates, not a known true winning probability.',
            'Historical spreads are proxies; entry features use previous closed-bar spread to avoid future-bar leakage.'])
    return model,report


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--csv',type=Path,help='Use previously exported bars, no MT5 connection')
    parser.add_argument('--bars',type=int,default=30000)
    parser.add_argument('--terminal',help='Optional terminal64.exe path for multiple MT5 installations')
    parser.add_argument('--commission',type=float,default=0.)
    parser.add_argument('--output',type=Path,default=Path('artifacts/ForexSmart-ml-model.csv'))
    parser.add_argument('--report',type=Path,default=Path('artifacts/ForexSmart-ml-report.json'))
    parser.add_argument('--install',type=Path,help='Explicit MT5 MQL5/Files directory; default auto from read-only export')
    args=parser.parse_args(argv)
    if args.commission<0 or not math.isfinite(args.commission) or args.bars<6000:parser.error('Custos/barras inválidos')
    install=args.install
    report=None
    try:
        source=args.csv
        if source is None:
            source=Path('data/forex-ml-bars.csv');automatic=export_mt5(source,args.bars,args.terminal)
            if install is None:install=automatic
        model,report=train(source,args.commission)
        args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,indent=2,ensure_ascii=False,allow_nan=False)+'\n',encoding='utf-8')
        if not report['qualified']:
            print('Modelo NÃO qualificado. Nenhum modelo foi instalado. Motivos:')
            print('Estado do teste:',report['diagnostics']['test']['operational_status'])
            print('Simulação diagnóstica sem Kelly (não autoriza operação):',report['diagnostics']['test']['diagnostic_without_kelly']['trades'],'trades')
            print('\n'.join(report['reasons']));print('Relatório:',args.report);return 2
        write_model(args.output,model,report,args.commission)
        if install is not None:
            if not install.is_dir() or install.name.lower()!='files' or install.parent.name.upper()!='MQL5':raise ValueError('Destino precisa ser MQL5/Files existente')
            destination=install/'ForexSmart-ml-model.csv'
            if destination.exists():shutil.copy2(destination,destination.with_suffix('.csv.backup'))
            shutil.copy2(args.output,destination)
        print('Modelo qualificado para avaliação em demo:',report['model_id']);print('Relatório:',args.report)
        if install is None:
            print('Modelo salvo somente em:',args.output,'; não foi copiado para o MT5. Consulte o relatório antes de instalar.')
        else:
            print('Modelo copiado para:',install)
            print('No EA: Carregar modelo, depois ATIVAR DEMO. Nenhuma sessão foi armada por este script.')
        return 0
    except (ValueError,ImportError,OSError) as exc:
        print('Preparo interrompido:',exc)
        if report is None:report=dict(qualified=False,reasons=[str(exc)])
        else:report['installation_error']=str(exc)
        try:
            args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,indent=2,ensure_ascii=False,allow_nan=False)+'\n',encoding='utf-8')
        except OSError:pass
        return 2

if __name__=='__main__':sys.exit(main())
