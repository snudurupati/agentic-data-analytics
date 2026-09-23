#!/usr/bin/env python3
"""
Generate the landing zone for episode 1.

    pip install faker
    ./generate_landing.py

Two nights of deliveries from four source systems, written as immutable dated
files. Deterministic: the same SEED always produces the same files.

Delivery patterns differ by source, the way they do in life:

  ERP   Oracle with CDC enabled, so the loader takes only what changed.
        Night one is the initial load, night two is a small changeset with
        op and change_ts columns.

  POS   A transaction feed. Each file holds that night's takings.

  CRM   Salesforce. An API with no concept of CDC, so you pull the whole
  ECOM  Shopify. object every night and work out the delta yourself.

This script lives in the vault rather than the repo on purpose. It describes
how the simulated world was built, which is the context the models under test
must not be able to read.
"""

import csv
import random
import shutil
from datetime import datetime, timedelta, timezone
from pathlib import Path

from faker import Faker

SEED = 20260801
ROOT = (
    Path(__file__).resolve().parent.parent
    / "episodes" / "01-still-a-data-engineer" / "analytics"
)
LANDING = ROOT / "landing"
INCOMING = ROOT.parent / "test-data"

D1, D2 = "20260721", "20260722"

fake = Faker("en_US")
Faker.seed(SEED)
rng = random.Random(SEED)


# The ingestion tool stamps every row it delivers with the time it pulled the
# batch. One value per sync, not per row. Point of sale has no ingestion tool,
# so those files carry nothing of the kind.
SYNCED = {"20260721": "2026-07-21T06:15:00Z", "20260722": "2026-07-22T06:15:00Z"}


def write(system: str, name: str, header: list[str], rows: list[list],
          base: Path = None, synced: str = None) -> None:
    d = (base or LANDING) / system
    d.mkdir(parents=True, exist_ok=True)
    p = d / f"{name}.csv"
    if synced:
        header = header + ["_ingested_at"]
        rows = [r + [SYNCED[synced]] for r in rows]
    with p.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    label = f"{'incoming' if base else 'landing'}/{system}/{p.name}"
    print(f"  {label:<44} {len(rows):>5} rows")


# ---------------------------------------------------------------------------
# The company universe. Every system knows some subset of these, under its own
# key and its own spelling. Nothing carries a shared identifier.
# ---------------------------------------------------------------------------

N_COMPANIES = 45
INDUSTRIES = ["Manufacturing", "Wholesale", "Construction", "Healthcare",
              "Transportation", "Retail", "Utilities", "Education"]
SUFFIXES = ["Inc.", "LLC", "Corp.", "Ltd.", "Group", "Holdings", "& Sons"]


def company_universe():
    seen, out = set(), []
    while len(out) < N_COMPANIES - 2:
        base = fake.company().replace(",", "")
        if base in seen:
            continue
        seen.add(base)
        out.append({"base": base, "industry": rng.choice(INDUSTRIES),
                    "city": fake.city(), "state": fake.state_abbr()})
    # A parent and a spun-off division. Separate entities, separate contracts,
    # and they will always look like the same company.
    for nm in ("Sterling Fabrication", "Sterling Fabrication Group"):
        out.append({"base": nm, "industry": "Manufacturing",
                    "city": "Akron", "state": "OH"})
    return out


COMPANIES = company_universe()

crm_name = lambda b: f"{b} {rng.choice(SUFFIXES)}"
erp_name = lambda b: f"{b} {rng.choice(SUFFIXES)}".upper().replace(".", "").replace("&", "AND")


def ecom_name(b):
    w = b.split()
    return " ".join(w[:2]) if len(w) > 2 and rng.random() < 0.6 else b


def sf_id(i):
    return "001" + f"{i:05d}" + "".join(rng.choices("abcdefghijklmnopqrstuvwxyz0123456789", k=10))


# ---------------------------------------------------------------------------
# CRM: Salesforce. Full snapshot every night.
# ---------------------------------------------------------------------------

CRM_HEADER = ["Id", "Name", "Industry", "BillingCity", "BillingState",
              "AccountSource", "Owner", "LastModifiedDate"]

crm_n1 = []
for i, c in enumerate(COMPANIES):
    if rng.random() < 0.12:
        continue
    mod = fake.date_time_between(datetime(2025, 1, 1), datetime(2026, 7, 20),
                                 tzinfo=timezone.utc)
    crm_n1.append([sf_id(i), crm_name(c["base"]), c["industry"], c["city"],
                   c["state"],
                   rng.choice(["Referral", "Trade Show", "Web", "Cold Call", "Partner"]),
                   fake.name(), mod.strftime("%Y-%m-%dT%H:%M:%S.000+0000")])

# Night two is the whole object again. A handful of records have moved on:
# a couple of owner reassignments and an industry reclassification.
crm_n2 = [r[:] for r in crm_n1]
for idx in rng.sample(range(len(crm_n2)), 4):
    r = crm_n2[idx]
    if rng.random() < 0.5:
        r[6] = fake.name()
    else:
        r[2] = rng.choice(INDUSTRIES)
    r[7] = "2026-07-21T" + f"{rng.randint(9,20):02d}:{rng.randint(0,59):02d}:11.000+0000"

# ---------------------------------------------------------------------------
# E-commerce: Shopify. Full snapshot every night.
# ---------------------------------------------------------------------------

ECOM_HEADER = ["customer_id", "company_name", "email_domain", "contact_email",
               "country", "created_at", "updated_at"]

ecom_n1 = []
for c in COMPANIES:
    if rng.random() < 0.45:
        continue
    cid = "cus_" + "".join(rng.choices("abcdefghijklmnopqrstuvwxyz0123456789", k=8))
    created = fake.date_time_between(datetime(2021, 6, 1), datetime(2026, 7, 19),
                                     tzinfo=timezone.utc)
    dom = c["base"].lower().replace(" ", "").replace(",", "").replace("'", "")[:18] + ".com"
    ecom_n1.append([cid, ecom_name(c["base"]), dom,
                    fake.first_name().lower() + "@" + dom, "US",
                    created.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    created.strftime("%Y-%m-%dT%H:%M:%SZ")])

ecom_n2 = [r[:] for r in ecom_n1]
for idx in rng.sample(range(len(ecom_n2)), 3):
    r = ecom_n2[idx]
    r[3] = fake.first_name().lower() + "@" + r[2]
    r[6] = "2026-07-21T" + f"{rng.randint(9,20):02d}:{rng.randint(0,59):02d}:04Z"
# and one genuinely new signup
_new = COMPANIES[3]
_dom = _new["base"].lower().replace(" ", "")[:18] + ".com"
ecom_n2.append(["cus_" + "".join(rng.choices("abcdefghijklmnopqrstuvwxyz0123456789", k=8)),
                ecom_name(_new["base"]), _dom, fake.first_name().lower() + "@" + _dom,
                "US", "2026-07-21T14:22:09Z", "2026-07-21T14:22:09Z"])

# ---------------------------------------------------------------------------
# ERP: Oracle with CDC. Night one is the initial load, night two the changes.
# ---------------------------------------------------------------------------

CDC = ["op", "change_ts"]


def cdc(op, when="2026-07-21"):
    return [op, f"{when} {rng.randint(1,23):02d}:{rng.randint(0,59):02d}:{rng.randint(0,59):02d}-05:00"]


ERP_CUST_HEADER = ["customer_number", "customer_name", "industry_code", "city",
                   "state", "credit_limit", "created_on", "updated_on"] + CDC

erp_cust_n1, erp_numbers = [], {}
for i, c in enumerate(COMPANIES):
    if rng.random() < 0.22:
        continue
    num = 1000000 + (i * 137) + rng.randint(1, 90)
    erp_numbers[c["base"]] = num
    created = fake.date_time_between(datetime(2019, 1, 1), datetime(2024, 12, 31))
    upd = fake.date_time_between(created, datetime(2026, 7, 20))
    erp_cust_n1.append([num, erp_name(c["base"]), c["industry"][:4].upper(),
                        c["city"].upper(), c["state"],
                        rng.choice([25000, 50000, 100000, 250000, 500000]),
                        created.strftime("%Y-%m-%d %H:%M:%S-05:00"),
                        upd.strftime("%Y-%m-%d %H:%M:%S-05:00")] + cdc("I", "2026-07-20"))

erp_cust_n2 = []
for idx in rng.sample(range(len(erp_cust_n1)), 3):          # credit limit reviews
    r = erp_cust_n1[idx][:]
    r[5] = rng.choice([50000, 100000, 250000, 500000, 750000])
    r[7] = "2026-07-21 11:04:22-05:00"
    r[8], r[9] = cdc("U")
    erp_cust_n2.append(r)
r = erp_cust_n1[-1][:]                                       # one account closed
r[8], r[9] = cdc("D")
erp_cust_n2.append(r)

ERP_PROD_HEADER = ["product_id", "sku", "product_name", "category", "uom",
                   "unit_cost", "list_price"] + CDC
CATEGORIES = ["Fasteners", "Hand Tools", "Power Tools", "Safety", "Abrasives",
              "Electrical", "Plumbing", "Adhesives"]

erp_prod_n1 = []
for i in range(1, 61):
    cat = rng.choice(CATEGORIES)
    cost = round(rng.uniform(2.5, 380.0), 2)
    erp_prod_n1.append([4000 + i, f"{cat[:3].upper()}-{rng.randint(1000,9999)}",
                        f"{fake.word().capitalize()} {rng.choice(['Assembly','Kit','Set','Unit','Pack'])}",
                        cat, "EA", cost, round(cost * rng.uniform(1.35, 2.4), 2)]
                       + cdc("I", "2026-07-20"))

erp_prod_n2 = []
for idx in rng.sample(range(len(erp_prod_n1)), 5):           # price list update
    r = erp_prod_n1[idx][:]
    r[6] = round(r[6] * rng.uniform(1.02, 1.09), 2)
    r[7], r[8] = cdc("U")
    erp_prod_n2.append(r)

ERP_BRANCH_HEADER = ["branch_id", "branch_name", "city", "state", "timezone",
                     "opened_date"] + CDC
BRANCHES = [
    ("BR01", "Chicago Central",  "Chicago",  "IL", "America/Chicago",     0.18, 0.42),
    ("BR02", "Newark Depot",     "Newark",   "NJ", "America/New_York",    0.39, 0.11),
    ("BR03", "Atlanta South",    "Atlanta",  "GA", "America/New_York",    0.41, 0.09),
    ("BR04", "Dallas North",     "Dallas",   "TX", "America/Chicago",     0.44, 0.10),
    ("BR05", "Denver Foothills", "Denver",   "CO", "America/Denver",      0.46, 0.07),
    ("BR06", "Portland River",   "Portland", "OR", "America/Los_Angeles", 0.43, 0.08),
    ("BR07", "Bozeman Rural",    "Bozeman",  "MT", "America/Denver",      0.48, 0.05),
    ("BR08", "Fresno Valley",    "Fresno",   "CA", "America/Los_Angeles", 0.45, 0.08),
]
erp_branch_n1 = [[b, n, c, s, tz,
                  fake.date_between(datetime(1998, 1, 1), datetime(2020, 1, 1))]
                 + cdc("I", "2026-07-20") for b, n, c, s, tz, _, _ in BRANCHES]
erp_branch_n1.append(["WEB", "Online Store", "", "", "UTC", "2019-04-01"] + cdc("I", "2026-07-20"))

erp_branch_n2 = [["BR05", "Denver Metro", "Denver", "CO", "America/Denver",
                  erp_branch_n1[4][5]] + cdc("U")]

ERP_OH_HEADER = ["order_number", "customer_number", "branch_id", "order_datetime",
                 "order_total", "currency", "status"] + CDC
ERP_OL_HEADER = ["order_number", "line_number", "product_id", "quantity",
                 "unit_price", "line_amount"] + CDC

oh_n1, oh_n2, ol_n1, ol_n2 = [], [], [], []
order_no = 500000
customers = list(erp_numbers.values())
for _ in range(230):
    order_no += rng.randint(1, 4)
    placed = fake.date_time_between(datetime(2026, 1, 5), datetime(2026, 7, 21, 23, 59))
    is_n2 = placed.date() == datetime(2026, 7, 21).date()
    branch = rng.choice([b[0] for b in BRANCHES] + ["WEB", "WEB"])
    total, lines = 0.0, []
    for ln in range(1, rng.choices([1, 2, 3, 4, 5, 6], weights=[18, 28, 24, 16, 9, 5])[0] + 1):
        p = rng.choice(erp_prod_n1)
        qty = rng.choices([1, 2, 5, 10, 25, 50], weights=[22, 20, 20, 18, 12, 8])[0]
        amt = round(qty * p[6], 2)
        total += amt
        lines.append([order_no, ln, p[0], qty, p[6], amt]
                     + cdc("I", "2026-07-21" if is_n2 else "2026-07-20"))
    row = [order_no, rng.choice(customers), branch,
           placed.strftime("%Y-%m-%d %H:%M:%S-05:00"), round(total, 2), "USD",
           rng.choices(["SHIPPED", "INVOICED", "OPEN"], weights=[60, 32, 8])[0]] \
        + cdc("I", "2026-07-21" if is_n2 else "2026-07-20")
    (oh_n2 if is_n2 else oh_n1).append(row)
    (ol_n2 if is_n2 else ol_n1).extend(lines)

# ---------------------------------------------------------------------------
# POS: branch terminals. Each file is one night's takings.
# Bozeman's link was down, so its 20th and 21st both arrive on the second night.
# Atlanta had a till reconciliation problem on the evening of the 21st and sent
# a second file behind the main one, carrying the same received_at.
# ---------------------------------------------------------------------------

POS_HEADER = ["transaction_id", "branch_id", "sale_datetime", "received_at",
              "sale_amount", "cost_amount", "item_count"]

margin = {b[0]: b[5] for b in BRANCHES}
share = {b[0]: b[6] for b in BRANCHES}
R1 = datetime(2026, 7, 21, 6, 15, tzinfo=timezone.utc)
R2 = datetime(2026, 7, 22, 6, 15, tzinfo=timezone.utc)
pos_n1, pos_n2, pos_supp = [], [], []
txn = 90000


def sale(bid, day, received, target, hours=(8, 19)):
    global txn
    txn += 1
    local = day.replace(hour=rng.randint(*hours), minute=rng.randint(0, 59),
                        second=rng.randint(0, 59))
    amt = round(rng.lognormvariate(4.1, 0.85), 2)
    target.append([f"T{txn}", bid, local.strftime("%Y-%m-%d %H:%M:%S"),
                   received.strftime("%Y-%m-%dT%H:%M:%SZ"), amt,
                   round(amt * (1 - margin[bid]) * rng.uniform(0.97, 1.03), 2),
                   rng.choices([1, 2, 3, 4, 6], weights=[30, 26, 20, 14, 10])[0]])


for bid, *_ in BRANCHES:
    if bid == "BR07":
        continue
    for _ in range(int(share[bid] * 900)):
        sale(bid, datetime(2026, 7, 20), R1, pos_n1)

for bid, *_ in BRANCHES:
    for _ in range(int(share[bid] * 900)):
        sale(bid, datetime(2026, 7, 21), R2, pos_n2)
for day in (datetime(2026, 7, 20), datetime(2026, 7, 21)):
    for _ in range(int(share["BR07"] * 900)):
        sale("BR07", day, R2, pos_n2)

for _ in range(28):
    sale("BR03", datetime(2026, 7, 21), R2, pos_supp, hours=(16, 21))


# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # This deletes and rewrites the committed Episode 1 landing zone. Run it only
    # to reproduce those files. Check `git status` afterwards: a clean run leaves
    # every file byte-identical to what is committed.
    if LANDING.exists():
        shutil.rmtree(LANDING)
    if INCOMING.exists():
        shutil.rmtree(INCOMING)

    print(f"\nWriting to {ROOT}\n")

    write("crm",  f"account_{D1}",       CRM_HEADER,        crm_n1, synced=D1)
    write("crm",  f"account_{D2}",       CRM_HEADER,        crm_n2, synced=D2)

    write("ecom", f"customer_{D1}",      ECOM_HEADER,       ecom_n1, synced=D1)
    write("ecom", f"customer_{D2}",      ECOM_HEADER,       ecom_n2, synced=D2)

    write("erp",  f"customer_{D1}",      ERP_CUST_HEADER,   erp_cust_n1, synced=D1)
    write("erp",  f"customer_{D2}",      ERP_CUST_HEADER,   erp_cust_n2, synced=D2)
    write("erp",  f"product_{D1}",       ERP_PROD_HEADER,   erp_prod_n1, synced=D1)
    write("erp",  f"product_{D2}",       ERP_PROD_HEADER,   erp_prod_n2, synced=D2)
    write("erp",  f"branch_{D1}",        ERP_BRANCH_HEADER, erp_branch_n1, synced=D1)
    write("erp",  f"branch_{D2}",        ERP_BRANCH_HEADER, erp_branch_n2, synced=D2)
    write("erp",  f"order_header_{D1}",  ERP_OH_HEADER,     oh_n1, synced=D1)
    write("erp",  f"order_header_{D2}",  ERP_OH_HEADER,     oh_n2, synced=D2)
    write("erp",  f"order_line_{D1}",    ERP_OL_HEADER,     ol_n1, synced=D1)
    write("erp",  f"order_line_{D2}",    ERP_OL_HEADER,     ol_n2, synced=D2)

    write("pos",  f"transaction_{D1}",   POS_HEADER,        pos_n1)
    write("pos",  f"transaction_{D2}",   POS_HEADER,        pos_n2)

    # Held back. Copied into landing/pos/ during the demo, after the first run.
    write("pos",  f"transaction_{D2}_b", POS_HEADER,        pos_supp, base=INCOMING)

    print()
