# Warehouse conventions

These are standing business rules. Read this before building anything. 

How we build is in `STANDARDS.md`.

---

## Source File Definition

| Feed Source | Feed Type |
|---|---|
| **CRM**, **e-commerce** | Full table dump |
| **ERP** | Change Data Feed, tagged `op` I/U/D with `change_ts` |
| **Point of sale** | New sales and any corrections |

### How Deletions are handled

In ERP a deleted row arrives with `op = 'D'`.

In snapshot feeds, a record only stops appearing when it has been deleted.

---

## Data Feed Owners

| Feed | How it reaches us | What we can ask for | Who we ask |
|---|---|---|---|
| **CRM** (Salesforce) | Managed connector | Arrival metadata, a sync identifier, per-sync row counts | Ingestion team |
| **ERP** (Oracle) | Managed connector, change feed | The same. They own the CDC configuration and can change it | Ingestion team |
| **E-commerce** (Shopify) | Managed connector | The same | Ingestion team |
| **Point of sale** | Branch tills push a file to shared storage overnight | Nothing | *nobody* |

The ingestion system stamps every row it delivers with `_ingested_at`, the time it pulled the batch. That is one value per sync, not per row. If we need more than the feed carries, we ask the ingestion team.

Point of sale has no ingestion system. The tills write the file and push it, so those files carry no ingestion timestamp.

POS feeds don't have an owner. Everything the tills write, `received_at` included, can change meaning without warning.

---

## Point of sale Specs

**The till timestamps are local times.** `sale_datetime` is that branch's local time, no timezone is shared, it can be derived based on branch location.

**Sales arrive late, and that is normal.** A branch with a bad link sends nothing for a day, then sends two days at once.

**A branch can send more than one file in a night.** Tills push per branch, and a second file can follow the first.

**The branches do not run the same till software.** Tills are from various vendors over 15 years. There is no shared specification, no shared version and no central upgrade. Each till numbers its own sales, and nothing coordinates one branch with another.

**Transaction IDs are not unique across branches.**

**Refunds, returns and exchanges are new transactions.** Each one gets its own transaction ID and carries a negative amount. An exchange can carry a negative, zero or positive amount depending on what was swapped. They can happen upto 14 days after the original sale, at a different branch, on a different till.

**Nothing in the feed links a refund back to the sale it reverses.** The till knows, the receipt knows, we do not.

**A refund reduces revenue on the day it arrives**, not the day of the original sale. A published number is not reopened to net off a refund.

**Voids behave differently from vendor to vendor.** A void happens before the sale settles, in the same shift. Some branches never send the original sale at all. Others send a zero-amount row reusing the original transaction ID.

**We count the website as a branch.** Online sales sit alongside the physical branches, so "by branch" includes the web. It has no city, no timezone and no opening date, because there is no building.

**This feed covers the physical tills only.** Web orders reach us through the ERP order feed. They never appear here.

**Point of sale carries a total and an item count.** There is no line detail and no customer.

---

## A period stays open for fourteen days

Finance allows fourteen days after the date of a sale for corrections. Voided sales, re-rung transactions, price adjustments, a till reconciled late: we expect all of it inside that window.

On day fifteen the period closes and the number is final. We have published it.

Anything that turns up after that is an exception, not a correction.

---

## When a feed is late

Last night's file is expected by 4am. A feed not received by then is late.

Point of sale is counted per branch. A branch that sends nothing is late even when the other seven arrive on time.

A late feed fails a test. It does not fail the job. Downstream work continues on whatever arrived.

The failed test appears on the observability dashboard. Someone reviews it and tells the business unit.

---

## We report a number as it was, not as it is now

When something about a customer, a product or a branch changes, the change applies from the day it happened. It does not reach backwards.

---

## We never delete

No hard deletes, at any layer.

Deleting a customer stops new activity. It does not erase history. Revenue we have already recognised against that customer stands. We reverse revenue for a void or a refund, never for a change to a customer record.

---

## Three kinds of date

We call three different things a date:

- **When it happened.** `sale_datetime`, `order_datetime`. Business time.
- **When the source recorded it.** `LastModifiedDate`, `updated_at`, `change_ts`.
- **When we received it.** `_ingested_at`, written by the ingestion system.

Point of sale has no arrival date. `received_at` sits in the file, but the till writes it, not us. It is one value per file and nobody owns the field.

---

## The three customer lists do not share a key

We hold `crm.account.Id`, `erp.customer.customer_number` and `ecom.customer.customer_id`. Three populations, no shared identifier, and company names spelled differently in all three. `email_domain` is the only bridge we have and it is unreliable.

There is no lookup table and no correct answer waiting somewhere. Any matching logic is a judgement, so the sales manager signs it off before it goes near a mart.
