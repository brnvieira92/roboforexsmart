"""Audit v3 ML stages without mixing v2 signals or guessing executions."""
import argparse
from collections import Counter,defaultdict
import json
try:
    from .history_report import read_events
    from .plan_report import fields,closed_statistics
except ImportError:
    from history_report import read_events
    from plan_report import fields,closed_statistics


def analyze(path):
    bars=defaultdict(set);counts=Counter();rejections=Counter();sessions=[];closed={}
    for event in read_events(path):
        detail=fields(event['detail']);kind=event['event']
        relevant=kind.startswith('ml_') or detail.get('strategy')=='ML_PA_V1' or (kind=='reject' and event['detail'].startswith('ML_PA_V1 |'))
        if not relevant:continue
        counts[kind]+=1
        if kind=='ml_score':bars[detail.get('symbol','UNKNOWN')].add(detail.get('bar'))
        if kind=='reject':rejections[event['detail']]+=1
        if kind in ('ml_init','ml_session','ml_fault'):sessions.append(event)
        if kind=='plan_exit' and detail.get('fully_closed')=='1':closed[detail['position']]=detail
    return dict(events=dict(counts),evaluated_closed_bars={s:len(v) for s,v in bars.items()},rejections=dict(rejections),
        recent_session_events=sessions[-20:],closed_position_statistics=closed_statistics(list(closed.values())),
        note='Two directional scores are one analyzed bar. A plan is not an order; dispatch is not proof of fill. Closed-result statistics exclude floating drawdown.')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('journal')
    print(json.dumps(analyze(parser.parse_args().journal),indent=2,ensure_ascii=False))
