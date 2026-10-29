"""Audit actual deals and version-3 planner exits, without synthesizing a backtest."""
import argparse
from collections import Counter, defaultdict
from decimal import Decimal
import json
try:
    from .history_report import read_events
except ImportError:
    from history_report import read_events


def fields(detail):
    return dict(part.strip().split('=', 1) for part in detail.split('|') if '=' in part)


def closed_statistics(records):
    values = [Decimal(d['cumulative_net']) for d in records]
    risk_values = [Decimal(d['net_R']) for d in records if 'net_R' in d]
    wins = sum((v for v in values if v > 0), Decimal('0'))
    losses = -sum((v for v in values if v < 0), Decimal('0'))
    peak = cumulative = drawdown = Decimal('0')
    for value in values:
        cumulative += value
        peak = max(peak, cumulative)
        drawdown = max(drawdown, peak - cumulative)
    return dict(closed_positions=len(values), net=str(sum(values, Decimal('0'))),
                positive=sum(v > 0 for v in values), negative=sum(v < 0 for v in values),
                breakeven=sum(v == 0 for v in values),
                profit_factor=str(wins / losses) if losses else None,
                observed_win_rate=str(Decimal(sum(v > 0 for v in values)) / len(values)) if values else None,
                mean_net_R=str(sum(risk_values) / len(risk_values)) if risk_values else None,
                closed_result_drawdown_currency=str(drawdown),
                mean_duration_seconds=str(sum(Decimal(d.get('duration_seconds', '0')) for d in records) / len(records)) if records else None,
                warning='Descriptive closed-position statistics; drawdown excludes floating equity. MAE/MFE are sampled, not tick-exact.')


def evaluate(path):
    events = read_events(path)
    positions = defaultdict(lambda: {'net': Decimal('0'), 'closed': False, 'strategy': '', 'symbol': ''})
    seen = set()
    rejection_counts = Counter()
    for event in events:
        if event['event'] == 'reject':
            rejection_counts[event['detail']] += 1
        if event['event'] != 'deal_metrics':
            continue
        d = fields(event['detail'])
        if d['deal'] in seen:
            continue
        seen.add(d['deal'])
        if d['strategy'] == 'EXTERNAL':
            continue
        p = positions[d['position']]
        amount = Decimal(d['net'])
        if not amount.is_finite():
            raise ValueError('Non-finite net result')
        p['net'] += amount
        p['strategy'], p['symbol'] = d['strategy'], d['symbol']
        # Historical simple exits are not proof that a position is fully closed:
        # a DEAL_ENTRY_OUT could be a partial. Require an explicit v3 exit for certainty.
        if d.get('entry') in ('1', '3'):
            p['has_exit_deal'] = True
    exits = {}
    for event in events:
        if event['event'] == 'plan_exit':
            d = fields(event['detail'])
            if d.get('fully_closed') == '1':
                exits[d['position']] = d
    groups = defaultdict(list)
    for record in exits.values():
        group = ':'.join(record.get(k, 'UNKNOWN') for k in ('strategy', 'symbol', 'regime', 'server_open_hour'))
        groups[group].append(record)
    result = {
        'events': len(events), 'events_by_type': dict(Counter(e['event'] for e in events)),
        'rejections': dict(rejection_counts),
        'automated_positions_seen': len(positions),
        'automated_deal_net_total': str(sum((p['net'] for p in positions.values()), Decimal('0'))),
        'positions': {k: {**p, 'net': str(p['net'])} for k, p in positions.items()},
        'v3_confirmed_closed_positions': len(exits),
        'v3_exit_records': list(exits.values()),
        'v3_closed_statistics': closed_statistics(list(exits.values())),
        'v3_by_strategy_symbol_regime_hour': {k: closed_statistics(v) for k, v in groups.items()},
        'limitations': ['Deal exits can be partial; historical full closure is not inferred.',
                        'No synthetic ticks, initial historical TP, or historical MAE/MFE are reconstructed.',
                        'This report is an execution audit, not an out-of-sample backtest.']
    }
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('journal')
    print(json.dumps(evaluate(parser.parse_args().journal), ensure_ascii=False, indent=2))
