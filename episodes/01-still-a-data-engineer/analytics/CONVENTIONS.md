# Warehouse conventions

Read this before you build anything. These are our standing rules. You cannot work most of them out from the data.

We do not list columns here. Those live in the source YAML and would go stale in two places.

---

## What "tonight's file" means, per system

The four systems do not agree, and everything else depends on this. If you assume one shape fits all four, your models will run clean and give wrong answers.

| Feed | What lands each night | What a straight read gives you |
|---|---|---|
| **CRM**, **e-commerce** | The whole table again | Two nights of 41 accounts reads as 82 rows |
| **ERP** | One full extract, then changes only, tagged `op` I/U/D with `change_ts` | Full history, and three rows for a customer we changed twice |
| **Point of sale** | New sales only. We never restate one | One row per sale |

### The two feed types handle deletion differently

The ERP tells us. A row arrives with `op = 'D'`.

The snapshot feeds do not tell us. A deleted record simply stops appearing. To find out, diff last night's snapshot against tonight's. If you skip that, a closed account stays open in the warehouse forever.

---

## Who owns each feed

You cannot see this in the files, and it decides whether a fix is even possible.

| Feed | How it reaches us | What we can ask for | Who we ask |
|---|---|---|---|
| **CRM** (Salesforce) | Managed connector | Arrival metadata, a sync identifier, per-sync row counts | *name the team* |
| **ERP** (Oracle) | Managed connector, change feed | The same. They own the CDC configuration and can change it | *name the team* |
| **E-commerce** (Shopify) | Managed connector | The same | *name the team* |
| **Point of sale** | Branch tills push a file to shared storage overnight | Nothing | *nobody* |

For the three connector feeds we can ask the source team to send us more, and often they already do. Fivetran stamps `_fivetran_synced`, Airbyte stamps `_airbyte_extracted_at`. Use those in preference to the source system's own modified timestamp.

For point of sale we can ask nobody. Everything the tills write, `received_at` included, can change meaning without warning, so do not build correctness on it.

When the point of sale data cannot answer a question, fail loudly. We would rather turn the build red than let a rule pick the wrong row quietly.

---

## Point of sale, what will not change

These are permanent, not gaps we intend to fill.

**The till clock has no offset.** `sale_datetime` is whatever the till says. Every other timestamp we hold carries an offset. The branch timezone lives in `erp.branch.timezone`, so join to it before you compare sales across branches. Otherwise you are comparing clocks that disagree.

**Sales arrive late, and that is normal.** A branch with a bad link sends nothing for a day, then sends two days at once. "Sales for the 20th" is never "the rows in the file named the 20th."

**A branch can send more than one file in a night.** Tills push per branch, and a second file can follow the first.

**The branches do not run the same till software.** We bought point of sale branch by branch over fifteen years, from more than one vendor. There is no shared specification, no shared version and no central upgrade. Each till numbers its own sales, and nothing coordinates one branch with another.

**We count the website as a branch.** Online sales sit alongside the physical branches, so "by branch" includes the web. It has no city, no timezone and no opening date, because there is no building.

**Point of sale carries a total and an item count.** There is no line detail and no customer. If you need product mix or customer attribution, this feed will never give it to you.

---

## A period stays open for fourteen days

Finance allows fourteen days after the date of a sale for corrections. Voided sales, re-rung transactions, price adjustments, a till reconciled late: we expect all of it inside that window.

On day fifteen the period closes and the number is final. We have published it.

Anything that turns up after that is an exception, not a correction. Applying it changes a number somebody has already acted on, so somebody has to decide. Do not apply it by default.

---

## We report a number as it was, not as it is now

When something about a customer, a product or a branch changes, the change applies from the day it happened. It does not reach backwards.

Say we reclassify a customer from Healthcare to Retail today. Every order they placed before today was placed by a Healthcare customer, and last month's Healthcare revenue does not move. The same goes for a product changing category or a branch changing name.

People break this rule by accident and nobody notices, because the number was right when we published it and only changed later.

---

## Every table carries audit columns

We write `inserted_ts` and `updated_ts` at load time, full timestamp with timezone. They are not optional.

We use them to order anything the source cannot order itself, and they are the first thing anyone asks for when a number looks wrong.

We stamp them ourselves rather than trust a source column. A source timestamp says when the source thinks something changed. Ours says when we actually saw it.

---

## We never delete

No hard deletes, at any layer.

When a CDC feed sends `op = 'D'`, mark the row deleted and keep it. Staging carries the flag through. What we do about it is a business decision, it belongs in the marts, and we need the record to still be there to make it.

Drop a delete in staging and nobody can ever answer when an account closed, or that it existed at all.

Deleting a customer stops new activity. It does not erase history. Revenue we have already recognised against that customer stands, and a report covering a past period does not change because somebody deleted them afterwards. We reverse revenue for a void or a refund, never for a change to a customer record.

---

## Layers

| Layer | What it is | What you do here |
|---|---|---|
| `landing/` | Files as they arrived. Immutable. | Nothing. Never edit a file in place. |
| Sources | Declarations over those files | Nothing. No filtering, no collapsing. Keep a source diffable against what is on disk. |
| Staging (`stg_`) | One model per source table | Rename, recast, collapse to current state, apply CDC operations, stamp audit columns |
| Marts (`dim_`, `fct_`) | Business facing | Joins, business rules, deletion policy |

A staging model reads one source table. Combine two and you are in the next layer up.

If you think in medallion terms: `landing/` and sources are bronze, staging is the front of silver, marts are gold.

---

## Always state the grain

Every model says what one row means, in words. "One row per order." "One row per branch per day."

Our most expensive mistakes have all been two tables at different grain joined together. The only thing that stops it is somebody writing the grain down and somebody else reading it.

---

## Timestamps are not interchangeable

We call three different things a date:

- **When it happened.** `sale_datetime`, `order_datetime`. Business time.
- **When the source recorded it.** `LastModifiedDate`, `updated_at`, `change_ts`.
- **When we received it.** `received_at`, or the connector's arrival column.

Never decide what is new from business time. Things happen out of order and arrive late.

---

## The three customer lists do not share a key

We hold `crm.account.Id`, `erp.customer.customer_number` and `ecom.customer.customer_id`. Three populations, no shared identifier, and company names spelled differently in all three. `email_domain` is the only bridge we have and it is unreliable.

Treat this as an unsolved project, not a missing join. There is no lookup table and no correct answer waiting somewhere. Any matching logic is a judgement, so the sales manager signs it off before it goes near a mart. This is sales data, and the person accountable for the number approves the rule that produces it.

---

## Write a test, not a sentence

Prose goes stale and nobody notices. A test tells you the day it stopped being true.

We have checked these and they hold today, so pin them as tests rather than writing them down as facts:

- `line_amount` equals `quantity * unit_price` on all 652 order lines.
- `order_total` matches the sum of its lines on all 230 orders, worst gap 0.00.
- Every foreign key a newcomer would join on is clean.

If you assert something here, bring the query with it, so the next person can re-run it in ten seconds instead of working it out again.

---

## Definition of done

A model is finished when:

- you have written down its grain;
- it has a uniqueness test on that grain and `not_null` on the key;
- you have run it twice and the second run did what you expected;
- somebody else could read the file and tell what it does and why.

---

## Open questions

We keep these here so the document does not turn into confident nonsense. Each one changes a design decision, and none of them has an answer yet.

- A branch goes silent for a night. Is that a one-off or does it happen regularly, and to which branches?
- When a till voids a sale, does it reuse the transaction ID or issue a new one, and does it send zero or a negative amount?
- Do the snapshot feeds ever drop a record, and does anyone need to know when they do?
- What does the connector actually expose? Nobody has asked.

---

## Raise these, do not solve them

Some problems do not belong in the warehouse. Send them back to a person.

- A source starts sending a column we did not expect, or stops sending one.
- The same key arrives twice in one batch on a feed with nothing to order the two rows by. The ERP change feed is not one of these, it stamps every row.
- A feed goes quiet in a way that looks like a slow day.
- Somebody needs a rule that nobody has written down.

Give us a failing test and a question, not a clever default.
