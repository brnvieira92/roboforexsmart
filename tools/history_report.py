"""Read the MT5 journal without external dependencies or network access."""
import argparse
import csv
import json
from collections import Counter
from pathlib import Path


def summarize(path):
    events = []
    with Path(path).open(encoding="utf-8-sig", errors="replace", newline="") as stream:
        for row in csv.reader(stream, delimiter=";"):
            if len(row) != 3:
                raise ValueError("Expected three journal columns")
            events.append(dict(time=row[0], event=row[1], detail=row[2]))
    return {"events": len(events), "counts": dict(Counter(e["event"] for e in events)), "recent": events[-20:]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("journal", type=Path)
    args = parser.parse_args()
    print(json.dumps(summarize(args.journal), ensure_ascii=False, indent=2))
