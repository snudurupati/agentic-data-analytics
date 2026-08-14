# Warehouse conventions

Read this before you build anything. These are our standing rules. You cannot work most of them out from the data.

We do not list columns here. Those live in the source YAML and would go stale in two places.

How we build is in `STANDARDS.md`.

---

## Source File Definition

| Feed Source | Feed Type |
|---|---|
| **CRM**, **e-commerce** | Full table dump |
| **ERP** | Change Data Feed, tagged `op` I/U/D with `change_ts` |
| **Point of sale** | New sales and any corrections |

### How Deletions are handled

In ERP a row arrives with `op = 'D'`.

In snapshot feeds, a record only stops appearing when it has been deleted.

---

## Data Feed Owners

| Feed | How it reaches us | What we can ask for | Who we ask |
|---|---|---|---|
| **CRM** (Salesforce) | Managed connector | Arrival metadata, a sync identifier, per-sync row counts | Ingestion team |
| **ERP** (Oracle) | Managed connector, change feed | The same. They own the CDC configuration and can change it | Ingestion team |
| **E-commerce** (Shopify) | Managed connector | The same | Ingestion team |
| **Point of sale** | Branch tills push a file to shared storage overnight | Nothing | *nobody* |

The connectors send what is in the feed today. Fivetran stamps `_fivetran_synced`, Airbyte stamps `_airbyte_extracted_at`. If we need more than that, we ask the ingestion team.

POS feeds don't have an owner. Everything the tills write, `received_at` included, can change meaning without warning.

---

## Point of sale Specs

**The till timestamps are local times.** `sale_datetime` is that branch's local time, no timezone is shared, it can be derived based on branch location.

**Sales arrive late, and that is normal.** A branch with a bad link sends nothing for a day, then sends two days at once.

**A branch can send more than one file in a night.** Tills push per branch, and a second file can follow the first.

**The branches do not run the same till software.** Tills are from various vendors over 15 years. There is no shared specification, no shared version and no central upgrade. Each till numbers its own sales, and nothing coordinates one branch with another.

**Transaction IDs are not unique across branches.**

**Corrections reuse the transaction ID.** A void comes back as the same transaction ID with a zero amount. A refund comes back as the same transaction ID with a negative amount. An exchange comes back as the same transaction ID, and the amount can be negative, zero or positive.

**We count the website as a branch.** Online sales sit alongside the physical branches, so "by branch" includes the web. It has no city, no timezone and no opening date, because there is no building.

**Point of sale carries a total and an item count.** There is no line detail and no customer.

---

## A period stays open for fourteen days

Finance allows fourteen days after the date of a sale for corrections. Voided sales, re-rung transactions, price adjustments, a till reconciled late: we expect all of it inside that window.

On day fifteen the period closes and the number is final. We have published it.

Anything that turns up after that is an exception, not a correction.

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
- **When we received it.** `received_at`, or the connector's arrival column.

---

## The three customer lists do not share a key

We hold `crm.account.Id`, `erp.customer.customer_number` and `ecom.customer.customer_id`. Three populations, no shared identifier, and company names spelled differently in all three. `email_domain` is the only bridge we have and it is unreliable.

There is no lookup table and no correct answer waiting somewhere. Any matching logic is a judgement, so the sales manager signs it off before it goes near a mart.
