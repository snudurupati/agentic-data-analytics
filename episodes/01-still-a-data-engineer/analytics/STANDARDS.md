# Warehouse standards

How we build. The business rules themselves are in `CONVENTIONS.md`.

---

## Layers

| Layer | What it is | What you do here |
|---|---|---|
| `landing/` | Files as they arrived. Immutable. | Nothing. Never edit a file in place. |
| Sources | Declarations over those files | Nothing. No filtering, no collapsing. Keep a source diffable against what is on disk. |
| Staging (`stg_`) | One model per source table | Rename, recast, collapse to current state, apply CDC operations, stamp audit columns |
| Marts (`dim_`, `fct_`) | Business facing | Joins, business rules, deletion policy |

A staging model maps to one exactly one source table. So staging model is at the grain of the source.

---

## Naming

Lower snake case everywhere. No abbreviations except the ones in this table.

| What | Pattern | Example |
|---|---|---|
| Source | as the source system names it | `erp.order_line` |
| Staging model | `stg_<system>__<entity>`, entity plural | `stg_erp__order_lines` |
| Dimension | `dim_<entity>`, singular | `dim_customer` |
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
- it has a uniqueness test on that grain and `not_null` on the key;
- somebody else could read the file and tell what it does and why.
