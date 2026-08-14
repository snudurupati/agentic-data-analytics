# Warehouse conventions

Read this before building anything. These are standing rules, and most of them are not
discoverable from the data.

Column lists are not repeated here. They live in the source YAML and would rot in two places.

---

## What "tonight's file" means, per system

Everything else depends on this, and the four systems do not agree. Assume one shape applies to all
four and you get a model that runs clean and is wrong.

| Feed | Shape | So a straight read gives you |
|---|---|---|
| **CRM**, **e-commerce** | The complete table, re-landed every night | Two nights of 41 accounts reads as 82 rows |
| **ERP** | One full extract, then changes only, tagged `op` I/U/D with `change_ts` | Correct history, and three rows for a twice-updated record |
| **Point of sale** | Appends only. Nothing is ever restated | One row per sale, no overlap |

### The two feed types express deletion completely differently

The ERP says so out loud: a row arrives with `op = 'D'`.

**A snapshot feed expresses deletion by the row simply not being there.** Nothing announces it. The
only way to see it is to diff last night's snapshot against tonight's, and if you are not doing
that, a closed account quietly stays open in the warehouse forever.

Nobody works that out on their own. It is the single most missed thing about snapshot feeds.

---

## Source systems and who owns them

This is invisible in the files and it decides where a fix is even possible.

| Feed | How it arrives | What we can ask for | Who to ask |
|---|---|---|---|
| **CRM** (Salesforce) | Managed connector | Arrival metadata, a sync identifier, per-sync row counts | *name the team* |
| **ERP** (Oracle) | Managed connector, change feed | Same. The CDC configuration is theirs and can be changed | *name the team* |
| **E-commerce** (Shopify) | Managed connector | Same | *name the team* |
| **Point of sale** | Branch tills push a file to shared storage overnight | **Nothing.** Nobody owns the format. Eight branches, no central control | *nobody* |

**The consequence.** For the three connector feeds, "ask the source to send X" is a real option.
Connectors already stamp arrival: Fivetran writes `_fivetran_synced`, Airbyte writes
`_airbyte_extracted_at`. Prefer those over the source system's own modified timestamp.

For point of sale it is not an option at all. Anything the tills write, including `received_at`, is
an unowned field that can change meaning without notice. Do not build correctness on it.

**When point of sale data cannot express something, fail loudly.** A test that turns the build red
beats a rule that quietly picks the wrong row.

---

## Point of sale, specific ceilings

Four things about this feed that are permanent, not gaps to be filled later.

**Branch-local time, no offset.** `sale_datetime` is the till's own clock. Every other timestamp in
the warehouse carries an offset. The branch timezone lives only in `erp.branch.timezone`, so any
comparison across branches joins to it first. Comparing raw `sale_datetime` across branches is
comparing clocks that do not agree.

**Late arrival is normal, not exceptional.** A branch with a bad link uploads nothing for a day and
sends two days at once. So "sales for day X" is never "rows in the file named X."

**One night can produce several files.** Tills push per branch, and a branch can send a second file
behind the first.

**No line detail and no customer.** Point of sale carries a total and an item count, nothing more.
Anything needing product mix or customer attribution cannot come from this feed, ever.

---

## A period stays open for fourteen days

Finance allows fourteen days after the date of a sale for corrections to arrive. A voided sale, a re-rung transaction, a price adjustment, a till that was reconciled late: all of it is expected inside that window.

**On day fifteen the period closes.** The number is final. Anything arriving after that is not a normal correction, and it does not get applied quietly.

This is a business rule. It is not visible anywhere in the data, and no amount of profiling produces it.

### What it means for a load

- **The last fourteen days are open, not just last night.** A load that only considers the newest file is wrong on any day a correction arrives for an earlier one.
- **A row whose business date is more than fourteen days old is an exception.** Raise it. Do not apply it, and do not silently discard it either.
- **Restating a closed period needs a person.** There is a reason a number was published, and changing it after the fact is a decision with an owner.
- **Older than fourteen days does not need reprocessing.** A load has a bounded window, which is what makes the cost of a nightly run flat instead of growing with history.

### Why the window matters more than it looks

Without it, "load everything that might have changed" has no end, so either you reprocess all history every night or you pick an arbitrary cutoff and hope. The window is what makes the correct answer bounded.

---

## Every table carries audit columns

`inserted_ts` and `updated_ts`, full timestamp with timezone, written by us at load time.

Not optional. They are how we order anything the source cannot order itself, and they are the first
thing anyone asks for when a number looks wrong.

We stamp them ourselves rather than trusting a source column, because a source timestamp records
when the source thinks something changed, and ours records when we actually saw it.

---

## We never delete

No hard deletes anywhere, at any layer.

A CDC feed sending `op = 'D'` means the row is marked deleted, not removed. Staging keeps it and
carries the flag through. What to do about it is a business decision that belongs in the marts, and
it needs the record to still exist in order to be made.

Drop a delete in staging and nobody downstream can ever answer when an account closed, or that it
existed at all.

---

## Layers

| Layer | What it is | What happens here |
|---|---|---|
| `landing/` | Files as they arrived. Immutable. | Nothing. Never edit a file in place. |
| Sources | Declarations over those files | Nothing. No filtering, no collapsing. A source must be diffable against what is on disk. |
| Staging (`stg_`) | One model per source table | Rename, recast, collapse to current state, apply CDC operations, stamp audit columns |
| Marts (`dim_`, `fct_`) | Business-facing | Joins, business rules, deletion policy |

Staging reads exactly one source table. Combining two is the next layer up.

In medallion terms: `landing/` and sources are bronze, staging is the front of silver, marts are
gold.

---

## Grain is stated, always

Every model's documentation says what one row means, in words. "One row per order." "One row per
branch per day."

Most expensive warehouse mistakes are two tables at different grain joined together, and the only
defence is that somebody wrote the grain down and somebody else read it.

---

## Timestamps are not interchangeable

Three different things get called a date:

- **When it happened.** `sale_datetime`, `order_datetime`. Business time.
- **When the source recorded it.** `LastModifiedDate`, `updated_at`, `change_ts`.
- **When we received it.** `received_at`, or the connector's own arrival column.

**Never use business time to decide what is new.** Things happen out of order and arrive late.

---

## The three customer populations do not share a key

`crm.account.Id`, `erp.customer.customer_number`, `ecom.customer.customer_id`. Different
populations, no shared identifier, company names spelled differently in all three. `email_domain`
is the only plausible bridge and it is unreliable.

**This is an unsolved project, not a missing join.** There is no lookup table and no correct answer
sitting somewhere. Any matching logic is a judgement, and a human signs off on the rule before it
goes near a mart.

Everyone tries to join these in their first week. It does not work.

---

## What is true today is a test, not a sentence

Prose quietly becomes a lie. A test tells you the day it stops being true.

Currently verified and worth pinning as tests rather than writing down as facts:

- `line_amount` equals `quantity * unit_price` on all 652 order lines.
- `order_total` reconciles to the sum of its lines on all 230 orders, worst gap 0.00.
- Every foreign key a newcomer would join on is clean.

**Carry the query with the claim.** Anything asserted here should come with the SQL that establishes
it, so the next person re-runs it in ten seconds instead of re-deriving it in an afternoon.

---

## Definition of done

A model is not finished until:

- its grain is written down;
- it has a uniqueness test on that grain, and `not_null` on the key;
- it has been run twice, and the second run does what you expected;
- somebody other than you could tell from the file what it does and why.

---

## Open questions

A document that only records answers rots into confident wrongness. These have no answer yet, and
each one changes a design decision.

- When a branch goes silent for a night, is that a one-off or does it recur? Which branches?
- When a void happens, does the till reuse the transaction ID or issue a new one? Does it send zero or a negative amount?
- Do the snapshot feeds ever drop a record, and if so, does anyone need to know?
- What does the connector actually expose? Nobody has asked.
- Is `transaction_id` unique across all eight branches, or only within one?

---

## Things to raise rather than solve

Some problems are not fixable in the warehouse and should come back to a person:

- A source starts sending a column we did not expect, or stops sending one.
- The same key arrives twice in one batch with no way to tell which is newer.
- A feed goes quiet in a way that looks like a slow day.
- A rule is needed that nobody has written down.

The right output is a failing test and a question, not a clever default.
