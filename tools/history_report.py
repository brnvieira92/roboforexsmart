"""Read the MT5 journal without external dependencies or network access."""
import argparse
import csv
import json
import math
from collections import Counter
from pathlib import Path


def read_events(path):
    events = []
    with Path(path).open(encoding="utf-8-sig", errors="replace", newline="") as stream:
        for row in csv.reader(stream, delimiter=";"):
            if len(row) < 3:
                raise ValueError("Expected three journal columns")
            events.append(dict(time=row[0], event=row[1], detail=";".join(row[2:])))
    return events


def summarize(path):
    events = read_events(path)
    metrics = {}
    seen = set()
    for event in events:
        if event['event'] != 'deal_metrics':
            continue
        fields = dict(part.split('=', 1) for part in event['detail'].split('|'))
        key = fields['deal']
        if key in seen:
            continue
        seen.add(key)
        net, commission, swap = (float(fields[name]) for name in ('net', 'commission', 'swap'))
        if not all(math.isfinite(value) for value in (net, commission, swap)):
            raise ValueError('Non-finite monetary amount')
        group = fields['strategy'] + ':' + fields['symbol']
        bucket = metrics.setdefault(group, dict(deals=0, net=0.0, commission=0.0, swap=0.0))
        bucket['deals'] += 1
        bucket['net'] += net
        bucket['commission'] += commission
        bucket['swap'] += swap
    return {"deal_metrics": metrics, "events": len(events), "counts": dict(Counter(e["event"] for e in events)), "recent": events[-20:]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("journal", type=Path)
    args = parser.parse_args()
    print(json.dumps(summarize(args.journal), ensure_ascii=False, indent=2))
