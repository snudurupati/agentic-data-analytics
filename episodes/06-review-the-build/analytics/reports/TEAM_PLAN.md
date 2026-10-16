# Team plan

Build the warehouse from `landing/` through to the three reports in `REQUIREMENTS.md`.

Read with `CONVENTIONS.md` (business rules), `STANDARDS.md` (build standards) and
`REQUIREMENTS.md` (the reports). This plan does not restate those rules. It says who builds what,
in which order, and the choices the lead made where the documents leave the build shape open.

## The team

| Teammate | Builds | Starts |
|---|---|---|
| lead | Shared macros, this plan, the task list, the final build and report | First |
| `crm` | Staging for the CRM (Customer Relationship Management) feed | After T01 |
| `ecom` | Staging for the e-commerce feed | After T01 |
| `erp` | Staging for the ERP (Enterprise Resource Planning) feed, five tables | After T01 |
| `pos` | Staging for the POS (point of sale) feed | After T01 |
| `marts` | Intermediate models, dimensions, facts, the three reports | After T04 and T05 are done |

## File ownership

One owner per file. To change a file you do not own, send its owner a message.

| Owner | Files |
|---|---|
| lead | `dbt_project.yml`, `profiles.yml`, `macros/**`, `reports/**` |
| `crm` | `models/staging/crm/**`, `tests/crm/**` |
| `ecom` | `models/staging/ecom/**`, `tests/ecom/**` |
| `erp` | `models/staging/erp/**`, `tests/erp/**` |
| `pos` | `models/staging/pos/**`, `tests/pos/**` |
| `marts` | `models/intermediate/**`, `models/marts/**`, `tests/marts/**` |

Nobody edits `landing/**` or the existing Markdown files.

## Task list

The session has no shared task tool, so this table is the task list. The lead owns it and updates
it when a teammate reports a task done.

| ID | Task | Owner | Depends on | Status |
|---|---|---|---|---|
| T01 | Shared macros: `generate_surrogate_key`, `audit_columns`, generic tests `unique_combination_of_columns` and `source_columns_match`; one scratch dbt target per teammate in `profiles.yml` | lead | none | done |
| T02 | CRM source and `stg_crm__accounts`, with tests | `crm` | T01 | done |
| T03 | E-commerce source and `stg_ecom__customers`, with tests | `ecom` | T01 | done |
| T04 | ERP sources and `stg_erp__branches`, `stg_erp__customers`, `stg_erp__products`, `stg_erp__order_headers`, `stg_erp__order_lines`, with tests | `erp` | T01 | done |
| T05 | POS source and `stg_pos__transactions`, with tests, including the late feed test | `pos` | T01, T04 (the late feed test reads the branch list) | done |
| T06 | Dimensions `dim_branch`, `dim_product`, `dim_customer` | `marts` | T04 | done |
| T07 | Intermediate models for costed order lines and POS sales | `marts` | T04, T05, T06 | done |
| T08 | Reports `fct_order`, `fct_order_line`, `fct_daily_branch_sales`, with tests | `marts` | T06, T07 | done |
| T09 | Full `dbt build`, fix implementation errors, rerun | lead | T02 to T08 | done |
| T10 | `reports/BUILD_REPORT.md` | lead | T09 | done |

The marts do not read CRM or e-commerce staging. `REQUIREMENTS.md` forbids joining customers
across systems until the sales manager approves a matching rule, and no report needs those
systems otherwise. T02 and T03 still have to finish before T09.

## What the data shows (profiled by the lead before planning)

- Two nightly deliveries per system: 21 and 22 July 2026.
- ERP carries only `I` rows on day one. Day two carries `U` rows for one branch (BR05 renamed),
  five products (list price changes; `unit_cost` is unchanged, corrected after the `marts` teammate checked), three customers, and one customer `D` (1006043).
- ERP change feed starts on 20 July 2026. Orders go back to January 2026. Only 5 of 230 orders
  are dated on or after the first product `change_ts`.
- Order headers reconcile to the sum of their lines. Every line has `line_amount = quantity x unit_price`.
- Order statuses: `OPEN`, `SHIPPED`, `INVOICED`. Currency: `USD` only.
- `order_datetime` and `change_ts` all carry a `-05:00` offset.
- POS: 1,845 rows, `(branch_id, transaction_id)` is unique, no zero or negative amounts.
- POS BR07 sent no file on 21 July. Its 20 July sales arrived in the 22 July file.
- The WEB branch row carries `opened_date = 2019-04-01`. `CONVENTIONS.md` says it has none.
- CRM: four accounts changed between dumps, none disappeared.
- E-commerce: three customers changed, one new customer, none disappeared.

## Build decisions the lead made for every teammate

These fix the shape of the build where the documents leave it open. None of them is a business
rule. If one turns out to need a business decision, the teammate reports it and does not guess.

### Sources

- One source YAML per system, owned by that system's teammate: `models/staging/<system>/_<system>__sources.yml`.
- Each source table reads its folder through dbt-duckdb's `external_location`, all columns as text:

  ```yaml
  config:
    meta:
      external_location: "read_csv('landing/erp/branch_*.csv', filename = true, union_by_name = true, all_varchar = true)"
  ```

  `union_by_name` means a new or missing column does not stop the read. `all_varchar` keeps the
  source identical to the file on disk; staging does the casting. `filename` records which file
  each row came from.
- Every source table gets a `source_columns_match` test listing the columns the file carries today
  (including `filename`).

### Staging, all systems

- One model per source table, reading exactly that one source.
- Rename to the naming rules in `STANDARDS.md`, cast to real types.
- Business keys keep the source's own name (`Id` becomes `id` only if you must lower-case it; say so).
- `_ingested_at` becomes `ingested_ts`. `filename` becomes `source_file_name`.
- A source timestamp whose standard name would collide with an audit column takes a `source_`
  prefix. Example: ERP `updated_on` becomes `source_updated_ts`, not `updated_ts`.
- A staging surrogate key `stg_<entity>_key`, built with `generate_surrogate_key` over the grain
  columns. A singular entity name: `stg_branch_key`, `stg_order_line_key`.
- `{{ audit_columns() }}` last in the select list.
- A YAML file per system with the grain written in the model `description`, a
  `unique_combination_of_columns` test on the grain columns, and `not_null` on each grain column.

### Staging, change feeds (ERP)

- Every row is kept. Grain: one row per business key per `change_ts`.
- Keep `op` and add `is_deleted` (`op = 'D'`).

### Staging, full dumps (CRM, e-commerce)

- A snapshot is one value of `_ingested_at`. Order snapshots by it.
- For each record, keep its row in a snapshot when it is the first time we see the record, when
  any source-sent column differs from the row held before it, or when the record comes back
  after being marked deleted. Compare only source-sent columns, never `_ingested_at` or `filename`.
- When a record is present in one snapshot and absent from the next, add one row for it in the
  next snapshot with `is_deleted = true`, carrying the last held values.
- Grain: one row per record per snapshot in which it changed.

### Staging, POS

- Every row is kept unless an identical row (same source columns) is already held for the same
  `(branch_id, transaction_id)`.
- `sale_datetime` is branch local time with no zone. Keep it as a timestamp without time zone
  named `sale_local_ts`, and add `sale_date`. Do not convert it: that needs the branch table, and
  staging reads one source.
- `received_at` is written by the till and owned by nobody. Keep it as `received_ts`, and say so
  in the column description.

### Test severity

- Tests on grain, keys and accepted values: `error`.
- Tests that detect incoming data breaking a rule in `CONVENTIONS.md` (a late feed, an attribute
  the conventions say should be absent, a row arriving after its period closed): `warn`.
  `CONVENTIONS.md` says a late feed "fails a test. It does not fail the job." In `dbt build`
  an `error` test skips everything downstream, so these use `warn`.

### Marts

- Dimensions carry history as date-ranged rows from the ERP change feed: `valid_from_ts`
  (`change_ts`), `valid_to_ts` (the next `change_ts`, null for the open row), `is_current`,
  `is_deleted`. Grain: one row per business key per `valid_from_ts`.
- A fact carries the business keys the report names (`branch_id`, `order_number`, ...), and the
  dimension key of the row that was valid at the event time. Where no row was valid, the key
  is null. Nothing is back-filled.
- A report publishes numerators and denominators, never a rate.
- Where a number depends on a decision nobody has made, the column is null and a count column says
  how many inputs are affected. The gap is reported, not filled.

## Messages

- A teammate that finishes a task sends the lead a message: the task ID, the files written, the
  test result line.
- A teammate that fixes a column name or a grain another teammate reads sends that teammate a
  message. `erp` and `pos` send `marts` their final model names, grains and column lists.
- A teammate that is blocked on a business decision reports it to the lead and carries on with
  the rest.

## Commands

Run dbt from this directory with `../.venv/bin/dbt`, and only the narrowest command that checks
your task.

DuckDB lets one process write to a database file at a time, so each teammate builds into its own
scratch database and its own artifact folder. Both live under `target/`, which git ignores:

```bash
../.venv/bin/dbt build --target erp --target-path target/run_erp --select staging.erp
```

A teammate whose models read another teammate's models selects those parents too
(`--select +stg_pos__transactions`, `--select +path:models/marts`). Only the lead's final build
writes `analytics.duckdb`.
