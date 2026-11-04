"""ML_PA_V1 policy shared with the MT5 implementation; no trading API calls."""
from dataclasses import dataclass
import csv
import math
from pathlib import Path

SYMBOLS=('EURUSD#','USDJPY#','GBPUSD#','USDCHF#')
FEATURES=13
HORIZON=8
POLICY=1

@dataclass(frozen=True)
class Bar:
    time:int; open:float; high:float; low:float; close:float; spread:float
    point:float; tick:float; contract:float


def down(x,step):return math.floor(x/step+1e-9)*step

def up(x,step):return -math.floor(-x/step+1e-9)*step

def kelly(p,v):return p-(1-p)/v if 0<=p<=1 and v>0 else 0.

def features(bars,buy,spread):
    """Input newest CLOSED bar first, exactly 32 or more bars."""
    if len(bars)<32 or spread<0:raise ValueError('Insufficient closed bars/spread')
    a=sum(max(b.high-b.low,abs(b.high-bars[j+1].close),abs(b.low-bars[j+1].close)) for j,b in enumerate(bars[:14]))/14
    hi=max(b.high for b in bars[:20]);lo=min(b.low for b in bars[:20]);avg=sum(b.close for b in bars[:20])/20
    if a<=0 or hi<=lo:raise ValueError('Zero volatility')
    b=bars[0];sign=1 if buy else -1
    upper=b.high-max(b.open,b.close);lower=min(b.open,b.close)-b.low
    x=[sign*(b.close-b.open)/a,(lower if buy else upper)/a,(upper if buy else lower)/a,
       sign*(b.close-bars[1].close)/a,sign*(b.close-bars[3].close)/a,sign*(b.close-bars[7].close)/a,
       sign*(b.close-avg)/a,(b.close-lo)/(hi-lo) if buy else (hi-b.close)/(hi-lo),
       (hi-b.close if buy else b.close-lo)/a,(b.close-lo if buy else hi-b.close)/a,
       (b.high-b.low)/a,spread/a,sign*(bars[1].close-bars[1].open)/a]
    return [max(-10,min(10,v)) for v in x],a


def geometry(past,buy,entry,spread,tick):
    x,a=features(past,buy,spread)
    buffer=max(.1*a,spread)
    sl=down(min(b.low for b in past[:3])-buffer,tick) if buy else up(max(b.high for b in past[:3])+buffer+spread,tick)
    r=abs(entry-sl)
    if r<=0 or (buy and sl>=entry) or (not buy and sl<=entry):raise ValueError('Invalid structural SL')
    tp=up(entry+1.25*r,tick) if buy else down(entry-1.25*r,tick)
    return x,a,sl,tp,buffer


def profit(symbol,lot,entry,exit,contract):
    value=(exit-entry)*contract*lot
    return value/exit if symbol.startswith(('USDJPY','USDCHF')) else value


def trail(buy,entry,r,mark,b,buffer,spread,cost_distance,old,tick):
    if (mark-entry if buy else entry-mark)<r:return old
    candidate=max(entry+cost_distance,b.low-buffer) if buy else min(entry-cost_distance,b.high+buffer+spread)
    candidate=down(candidate,tick) if buy else up(candidate,tick)
    return max(old,candidate) if buy else min(old,candidate)


def simulate(symbol,past,future,buy,commission=0,spread_multiplier=1.):
    """Conservative OHLC label; never assumes target-first on ambiguous candles.

    Future begins at next bar open. Historical bar spread is an estimate, not ticks.
    Explicit 2-point adverse entry and exit slippage; trailing only after bar close.
    """
    if len(future)<HORIZON:raise ValueError('Missing horizon')
    first=future[0];spread=past[0].spread*spread_multiplier;sign=1 if buy else -1
    quote=first.open+(spread if buy else 0)
    entry=quote+sign*2*first.point
    x,a,sl,tp,buffer=geometry(past,buy,quote,spread,first.tick)
    r=abs(entry-sl)
    if r<=0:return None
    costs=commission+abs(profit(symbol,1,quote,quote-sign*4*first.point,first.contract))
    cost_distance=costs/abs(profit(symbol,1,quote,quote+first.tick,first.contract))*first.tick
    initial_loss=abs(profit(symbol,1,quote,sl,first.contract))+costs
    if initial_loss<=0:return None
    active=sl;exit_price=None;reason='HORIZON';both=False
    for index,b in enumerate(future[:HORIZON]):
        s=b.spread*spread_multiplier;bid_or_ask=b.open+(0 if buy else s)
        lo=b.low+(0 if buy else s);hi=b.high+(0 if buy else s)
        # A gap through a stop fills at the worse opening price, not the nominal SL.
        stop=lo<=active if buy else hi>=active
        target=hi>=tp if buy else lo<=tp
        if stop:
            raw=min(active,bid_or_ask) if buy else max(active,bid_or_ask)
            exit_price=raw-sign*2*b.point;reason='STOP';both=target
        elif target:exit_price=tp-sign*2*b.point;reason='TP'
        elif index==HORIZON-1:exit_price=b.close+(0 if buy else s)-sign*2*b.point
        if exit_price is not None:
            net=sign*profit(symbol,1,entry,exit_price,b.contract)-commission
            return dict(x=x,y=int(net>0),net_R=net/initial_loss,entry_time=first.time,
                exit_time=b.time+900,reason=reason,both_touched=both,symbol=symbol,buy=buy,
                initial_loss=initial_loss,win_per_lot=sign*profit(symbol,1,quote,tp,first.contract)-costs,
                duration=b.time+900-first.time)
        mark=b.close+(0 if buy else s)
        proposed=trail(buy,entry,r,mark,b,buffer,s,cost_distance,active,b.tick)
        # Broker distance is terminal-specific; no move on or beyond current mark.
        if (buy and proposed<mark-2*b.point) or (not buy and proposed>mark+2*b.point):active=proposed
    raise AssertionError('Missing terminal outcome')


def load_bars(path):
    data={s:[] for s in SYMBOLS}
    with Path(path).open(encoding='utf-8-sig',newline='') as f:
        for row in csv.DictReader(f):
            symbol=row['symbol']
            if symbol not in data:raise ValueError('Unexpected symbol')
            values={k:float(row[k]) for k in ('open','high','low','close','spread','point','tick','contract')}
            if not all(math.isfinite(v) for v in values.values()):raise ValueError('Non-finite bar')
            b=Bar(time=int(row['time']),**values)
            if b.low<=0 or b.high<max(b.open,b.close) or b.low>min(b.open,b.close) or b.spread<0 or min(b.point,b.tick,b.contract)<=0:raise ValueError('Invalid OHLC/specifications')
            if data[symbol] and b.time<=data[symbol][-1].time:raise ValueError('Duplicate/out-of-order bars')
            data[symbol].append(b)
    return data


def samples(data,commission=0,spread_multiplier=1.):
    result=[]
    for symbol,bars in data.items():
        for index in range(32,len(bars)-HORIZON+1):
            past=list(reversed(bars[index-32:index]));future=bars[index:index+HORIZON]
            if past[0].time+900!=future[0].time:continue
            for buy in (True,False):
                try:record=simulate(symbol,past,future,buy,commission,spread_multiplier)
                except ValueError:continue
                if record:result.append(record)
    return sorted(result,key=lambda r:(r['entry_time'],r['symbol'],not r['buy']))


def temporal_split(records):
    times=sorted({r['entry_time'] for r in records})
    if len(times)<100:raise ValueError('Insufficient time series for chronological split')
    a,b=times[int(.6*len(times))],times[int(.8*len(times))]
    # Purge labels crossing boundaries and leave one full holding horizon between blocks.
    train=[r for r in records if r['exit_time']<a-HORIZON*900]
    calibration=[r for r in records if r['entry_time']>=a and r['exit_time']<b-HORIZON*900]
    test=[r for r in records if r['entry_time']>=b]
    return train,calibration,test,dict(train_boundary=a,test_boundary=b,purge_seconds=HORIZON*900)


def portfolio(records,probabilities,threshold=.55,win_lower=None,payoff_lower=None):
    """One side per symbol/bar, at most two simultaneous positions; no hindsight ranking."""
    selected=[];active=[];current=None;batch=[]
    def process(group):
        nonlocal active
        active=[r for r in active if r['exit_time']>group[0][0]['entry_time']]
        used={r['symbol'] for r in active}
        for r,p in sorted(group,key=lambda item:(-item[1],item[0]['symbol'])):
            if p<threshold or len(active)>=2 or r['symbol'] in used:continue
            if win_lower is not None and payoff_lower is not None and kelly(min(float(p),win_lower),payoff_lower)<=0:continue
            if 'win_per_lot' in r and p*r['win_per_lot']-(1-p)*r['initial_loss']<=0:continue
            chosen={**r,'probability':float(p)};selected.append(chosen);active.append(chosen);used.add(r['symbol'])
    for r,p in zip(records,probabilities):
        if current is not None and r['entry_time']!=current:process(batch);batch=[]
        current=r['entry_time'];batch.append((r,p))
    if batch:process(batch)
    return selected


def statistics(records):
    records=sorted(records,key=lambda r:r['exit_time']);values=[r['net_R'] for r in records]
    wins=[x for x in values if x>0];losses=[-x for x in values if x<0];n=len(values)
    p=len(wins)/n if n else 0;z=1.96
    lower=(p+z*z/(2*n)-z*math.sqrt(p*(1-p)/n+z*z/(4*n*n)))/(1+z*z/n) if n else 0
    payoff=(sum(wins)/len(wins))/(sum(losses)/len(losses)) if wins and losses else 0
    running=peak=drawdown=0
    for v in values:running+=v;peak=max(peak,running);drawdown=max(drawdown,peak-running)
    return dict(trades=n,wins=len(wins),losses=len(losses),win_rate=p,win_lower=lower,payoff=payoff,
        net_R=sum(values),mean_R=sum(values)/n if n else None,
        profit_factor=sum(wins)/sum(losses) if losses else None,closed_drawdown_R=drawdown,
        mean_duration_seconds=sum(r['duration'] for r in records)/n if n else None,
        ambiguous_stop_first=sum(r['both_touched'] for r in records))
