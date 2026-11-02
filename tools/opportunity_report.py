"""Opportunity funnel, deduplicated by parent intent; never infers missed profits."""
import argparse
from collections import Counter, defaultdict
import json
import re
try:
    from .history_report import read_events
    from .plan_report import fields
except ImportError:
    from history_report import read_events
    from plan_report import fields

PLAN = re.compile(r'\bplan=([^ |;]+)')


def reason(detail):
    parts = [p.strip() for p in detail.split('|')]
    return next((p for p in reversed(parts) if '=' not in p), detail)


def analyze(path, start=None, end=None):
    events = [e for e in read_events(path)
              if (not start or e['time'] >= start) and (not end or e['time'] < end)]
    counts = Counter(e['event'] for e in events)
    intents = {}
    current = None
    by_plan = {}
    unassigned = Counter()
    def get(key, strategy='UNKNOWN', symbol='UNKNOWN'):
        return intents.setdefault(key, dict(strategy=strategy, symbol=symbol,
            signals=0, alternatives=0, rechecks=0, approvals=0, sends=0, fills=0,
            rejects=[], states=[], geometries=[]))
    for index, e in enumerate(events):
        d = fields(e['detail'])
        m = PLAN.search(e['detail'])
        plan = m.group(1) if m else None
        parent = d.get('opportunity') or (by_plan.get(plan, plan) if plan else None)
        if not parent and e['event'].startswith('recheck_'):
            symbol, bar = d.get('symbol'), d.get('bar', d.get('signal_bar'))
            matches = [key for key in intents if symbol and bar and key.startswith(symbol+'/') and key.endswith('/'+bar)]
            if len(matches) == 1:
                parent = matches[0]
        if e['event'] == 'opportunity_new':
            current = parent
            get(parent, d.get('strategy', 'UNKNOWN'), d.get('symbol', 'UNKNOWN'))
        elif e['event'] == 'signal':
            # Legacy journals: bind each signal to its first subsequent identified plan.
            if not current or (counts['opportunity_new'] == 0):
                current = None
                for following in events[index+1:]:
                    if following['event'] == 'signal':
                        break
                    match = PLAN.search(following['detail'])
                    if match:
                        current = match.group(1)
                        break
                if not current:
                    current = f"unidentified/{e['time']}/{index}"
            bucket = get(current)
            bucket['signals'] += 1
            bucket['symbol'] = e['detail'].split()[-1]
            if '/' in current and not current.startswith('unidentified/'):
                bucket['strategy'] = current.split('/')[1]
        key = parent or current
        if not key:
            unassigned[e['event']] += 1
            continue
        bucket = get(key, d.get('strategy', 'UNKNOWN'), d.get('symbol', 'UNKNOWN'))
        if plan:
            by_plan[plan] = key
        if d.get('strategy') and bucket['strategy'] == 'UNKNOWN':
            bucket['strategy'] = d['strategy']
        if d.get('symbol'):
            bucket['symbol'] = d['symbol']
        if e['event'] == 'recheck_attempt': bucket['rechecks'] += 1
        if e['event'] == 'opportunity_alternative': bucket['alternatives'] += 1
        if e['event'] == 'plan_accepted': bucket['approvals'] += 1
        if e['event'] == 'order_dispatch': bucket['sends'] += 1
        if e['event'] in ('order_fill', 'execution'): bucket['fills'] += 1
        if e['event'] == 'reject': bucket['rejects'].append(reason(e['detail']))
        if e['event'] == 'opportunity_state': bucket['states'].append(d.get('state'))
        if e['event'] in ('plan_geometry', 'plan_evaluation', 'plan_accepted'):
            bucket['geometries'].append(d)
    module_events = defaultdict(lambda: defaultdict(set))
    for e in events:
        d = fields(e['detail'])
        parent = d.get('opportunity')
        plan = d.get('plan')
        if not parent and plan:
            parent = by_plan.get(plan, plan)
        strategy = d.get('strategy') or (plan.split('/')[1] if plan and '/' in plan else None)
        symbol = d.get('symbol') or (plan.split('/')[0] if plan and '/' in plan else None)
        if parent and strategy and symbol and e['event'] in ('opportunity_alternative','plan_candidate','plan_accepted','order_dispatch','order_fill','plan_evaluation'):
            module_events[strategy+':'+symbol][e['event']].add(parent)
    groups = defaultdict(Counter)
    first, final = Counter(), Counter()
    stops = []
    for key, p in intents.items():
        group = groups[p['strategy'] + ':' + p['symbol']]
        group['opportunities'] += 1
        for metric in ('signals', 'rechecks', 'alternatives'):
            group[metric] += p[metric]
        group['approved_intents'] += bool(p['approvals'])
        group['sent_intents'] += bool(p['sends'])
        group['filled_intents'] += bool(p['fills'])
        group['rejected_intents'] += bool(p['rejects'])
        if p['rejects']:
            first[p['rejects'][0]] += 1
            final[p['rejects'][-1]] += 1
            if 'Stop técnico excede' in p['rejects'][0] and p['geometries']:
                g = p['geometries'][0]
                stops.append({k: g.get(k) for k in ('plan','entry','SL','SL_pips','WilderATR14','structure_time','obstacle_bid')})
        p['initial_rejection'] = p['rejects'][0] if p['rejects'] else None
        p['final_recorded_decision'] = p['states'][-1] if p['states'] else (p['rejects'][-1] if p['rejects'] else 'NO_FINAL_EVENT')
    return dict(events_by_type=dict(counts), opportunity_count=len(intents),
        first_rejections=dict(first), last_rejections=dict(final), stop_limit_cases=stops,
        by_strategy_symbol={k: dict(v) for k,v in groups.items()},
        by_module={k: {event: len(ids) for event,ids in counters.items()} for k,counters in module_events.items()}, intents=intents,
        unassigned_events=dict(unassigned), limitations=[
            'Legacy signals without a plan ID are associated with their first subsequent plan; unidentifiable signals remain explicit.',
            'Approvals/retries are events, not additional opportunities; a send is an attempt, not a confirmed fill.',
            'No tick path, future candles, slippage or out-of-sample performance is inferred.',
            'Final recorded decision may be a historical rejection, not a definitive economic outcome.'])

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('journal')
    parser.add_argument('--start', help='Inclusive MT5 server timestamp YYYY.MM.DD HH:MM:SS')
    parser.add_argument('--end', help='Exclusive MT5 server timestamp YYYY.MM.DD HH:MM:SS')
    args = parser.parse_args()
    print(json.dumps(analyze(args.journal, args.start, args.end), ensure_ascii=False, indent=2))
