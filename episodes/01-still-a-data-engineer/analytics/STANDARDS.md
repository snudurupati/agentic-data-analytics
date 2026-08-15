# Warehouse standards

These are BUILD Standards. The business rules themselves are in `CONVENTIONS.md`.

---

## Layers

| Layer | What it is | What you do here |
|---|---|---|
| `landing/` | Files as they arrived. Immutable. | Nothing. Never edit a file in place. |
| Sources | Declarations over those files | Nothing. No filtering, no collapsing. Keep a source diffable against what is on disk. |
| Staging (`stg_`) | One model per source table | Rename, recast, collapse to current state, apply CDC operations, stamp audit columns |
| Marts (`dim_`, `fct_`) | Business facing | Joins, business rules, deletion policy |

A staging model maps to exactly one source table. So a staging model is at the grain of the source.

A source reads whatever is in the folder. An unexpected column, or a missing one, does not stop the read. Tests report the change.

---

## Naming

Lower snake case everywhere. No abbreviations except the ones in this table.

| What | Pattern | Example |
|---|---|---|
| Source | as the source system names it | `erp.order_line` |
| Staging model | `stg_<system>__<entity>`, entity plural | `stg_erp__order_lines` |
| Dimension | `dim_<entity>`, singular | `dim_customer` |
| Intermediate model | `int_<what_it_does>` | `int_customers_matched` |
| Fact | `fct_<event>`, singular | `fct_order_line` |
| Singular test | `assert_<what_it_asserts>` | `assert_order_total_reconciles` |

Two underscores separate the system from the entity in a staging name, so you can always see where a model's data came from.

Columns:

- A surrogate key is `<entity>_key`. A foreign key to a dimension keeps that dimension's key name.
- A business key from the source keeps the source's own name.
- Booleans start `is_` or `has_`.
- Dates end `_date`. Timestamps end `_ts`.
- Money ends `_amount`. Counts end `_count`.

---

## Every table carries a surrogate key and audit columns

Every table in the warehouse has:

- a **surrogate key**, generated, single column;
- `inserted_ts` and `updated_ts`, full timestamp with timezone, written at load time.

---

## Always state the grain

Every model says what one row means, in words. "One row per order." "One row per branch per day."


## Definition of done

A model is finished when:

- the grain has been written;
- a uniqueness test on the columns that make the grain, not on the surrogate key;
- `not_null` on those columns;
- somebody else could read the file and tell what it does and why.

If no combination of columns is unique, the grain has not been defined yet. Do not add a generated key to make the test pass.

This is the floor, not the list. A column with a fixed set of values gets an accepted values test. Two numbers that should reconcile get a test that they do. A rule in CONVENTIONS.md that can be written as a test gets written as a test.
