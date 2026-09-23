#!/usr/bin/env python3
"""
Generate the third night of point-of-sale deliveries for episode 4.

    python3 tools/generate_pos_night3.py

Output goes to episodes/04-full-build/test-data/pos/. Those files are copied
into the landing zone during the episode, after the first build has run.

Deterministic: the same SEED always produces the same files.

The night carries the delivery patterns that CONVENTIONS.md describes:

  A refund is its own transaction. It carries its own id and a negative amount.
  It belongs to the branch that processed it, which need not be the branch that
  made the sale. Nothing in the feed links it to the original.

  Some tills send a void as a zero-amount row that reuses the original
  transaction id.

  Each till numbers its own sales. Nothing coordinates one branch with another,
  so the same transaction id can arrive from two branches on the same night.

  A branch can push a second file behind the first.
"""

import csv
import random
from datetime import datetime, timezone
from pathlib import Path

SEED = 20260723

ROOT = Path(__file__).resolve().parent.parent / "episodes" / "04-full-build"
LANDING = ROOT / "analytics" / "landing" / "pos"
INCOMING = ROOT / "test-data" / "pos"

SALE_DAY = datetime(2026, 7, 22)
RECEIVED = datetime(2026, 7, 23, 6, 15, tzinfo=timezone.utc)

HEADER = ["transaction_id", "branch_id", "sale_datetime", "received_at",
          "sale_amount", "cost_amount", "item_count"]

# branch: margin, share of a night's volume
BRANCHES = {
    "BR01": (0.18, 0.42), "BR02": (0.39, 0.11), "BR03": (0.41, 0.09),
    "BR04": (0.44, 0.10), "BR05": (0.46, 0.07), "BR06": (0.43, 0.08),
    "BR07": (0.48, 0.05), "BR08": (0.45, 0.08),
}

rng = random.Random(SEED)


def highest_transaction_number() -> int:
    """The largest transaction number already delivered."""
    n = 0
    for p in sorted(LANDING.glob("transaction_*.csv")):
        with p.open(newline="") as f:
            for row in csv.DictReader(f):
                t = row["transaction_id"]
                if t.startswith("T") and t[1:].isdigit():
                    n = max(n, int(t[1:]))
    return n


txn = highest_transaction_number()


def next_id() -> str:
    global txn
    txn += 1
    return f"T{txn}"


def sale(branch: str, tid: str = None, hours=(8, 19)) -> list:
    margin = BRANCHES[branch][0]
    local = SALE_DAY.replace(hour=rng.randint(*hours),
                             minute=rng.randint(0, 59),
                             second=rng.randint(0, 59))
    amount = round(rng.lognormvariate(4.1, 0.85), 2)
    cost = round(amount * (1 - margin) * rng.uniform(0.97, 1.03), 2)
    return [tid or next_id(), branch, local.strftime("%Y-%m-%d %H:%M:%S"),
            RECEIVED.strftime("%Y-%m-%dT%H:%M:%SZ"), amount, cost,
            rng.choices([1, 2, 3, 4, 6], weights=[30, 26, 20, 14, 10])[0]]


def write(directory: Path, name: str, rows: list) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{name}.csv"
    with path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(HEADER)
        w.writerows(rows)
    print(f"  test-data/pos/{path.name:<32} {len(rows):>5} rows")


main = []
for branch, (_, share) in BRANCHES.items():
    for _ in range(int(share * 900)):
        main.append(sale(branch))

# A refund processed at Dallas. Its own id, a negative amount, negative items.
refund = sale("BR04")
amount = round(rng.uniform(80.0, 420.0), 2)
refund[4] = -amount
refund[5] = -round(amount * (1 - BRANCHES["BR04"][0]), 2)
refund[6] = -rng.choice([1, 2])
main.append(refund)

# A void from a till that resends the original id carrying zero.
original = main[rng.randrange(len(main))]
main.append([original[0], original[1], original[2], original[3], 0.00, 0.00, 0])

# Two branches issue the same transaction id on the same night.
shared = next_id()
main.append(sale("BR06", tid=shared))
main.append(sale("BR08", tid=shared))

main.sort(key=lambda r: (r[2], r[0]))

# Atlanta pushes a second file behind the first, carrying the same received_at.
supplementary = sorted((sale("BR03", hours=(16, 21)) for _ in range(24)),
                       key=lambda r: r[2])


if __name__ == "__main__":
    print(f"\nWriting to {INCOMING}\n")
    write(INCOMING, "transaction_20260723", main)
    write(INCOMING, "transaction_20260723_b", supplementary)
    print()
