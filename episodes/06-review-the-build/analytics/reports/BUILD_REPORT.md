# Build report

The warehouse builds from `landing/` through staging, intermediate models, dimensions and the
three reports that `REQUIREMENTS.md` asks for.

**Final `dbt build` result line** (full project, `../.venv/bin/dbt build`, default target, writes
`analytics.duckdb`):

```
Done. PASS=165 WARN=3 ERROR=0 SKIP=0 NO-OP=0 REUSED=0 TOTAL=168
```

The first full build gave this result. No implementation error needed fixing at that stage.
Each teammate had already fixed its own errors in its scratch database. The three warnings are
data findings, explained below.

## Counts

| What | Count | Names |
|---|---|---|
| Sources (source tables) | 8 | `crm.account`, `ecom.customer`, `erp.branch`, `erp.customer`, `erp.product`, `erp.order_header`, `erp.order_line`, `pos.transaction` |
| Staging models | 8 | `stg_crm__accounts`, `stg_ecom__customers`, `stg_erp__branches`, `stg_erp__customers`, `stg_erp__products`, `stg_erp__order_headers`, `stg_erp__order_lines`, `stg_pos__transactions` |
| Intermediate models | 5 | `int_order_headers_current`, `int_order_lines_current`, `int_order_lines_costed`, `int_order_sales_by_branch_day`, `int_pos_sales_by_branch_day` |
| Marts | 6 | Dimensions `dim_branch`, `dim_customer`, `dim_product`. Facts `fct_order`, `fct_order_line`, `fct_daily_branch_sales` |
| Tests | 149 | 118 generic (YAML), 31 singular. 129 at severity error, 20 at severity warn. 16 of them run on sources |

The 168 nodes in the build line are 19 models and 149 tests.

## The reports

| Report | Grain | Rows |
|---|---|---|
| `fct_daily_branch_sales` | One row per branch per sale date, only where the branch had a till sale or an order that day | 227 |
| `fct_order` | One row per order | 230 |
| `fct_order_line` | One row per order line | 652 |

Each carries the columns `REQUIREMENTS.md` names, without renaming. The daily report reconciles
to its inputs: 2,075 transactions are 1,845 till rows plus 230 orders.

**Read before using the numbers:**
- Revenue, transaction count and item count are populated on all 227 daily rows.
- Cost and margin are populated on only 15 daily rows, and 643 of 652 order lines have no cost.
  See decision 1 below.
- `order_date`, and so the `sale_date` of order sales, is provisional. See decision 2.
- `fct_order.branch_key` is set on 5 of 230 orders and `customer_key` on 4. The dimensions
  start when the ERP (Enterprise Resource Planning) change feed started, and nothing is
  back-filled.

## The three warnings

| Test | Result | Meaning |
|---|---|---|
| `assert_pos_branch_sent_rows_each_night` | 1 row | Branch BR07 sent no POS (point of sale) rows in the 21 July file. Its 20 July sales arrived in the 22 July file. This is the late feed rule in `CONVENTIONS.md`: it fails a test, not the job. |
| `assert_web_branch_has_no_city_timezone_or_opened_date` | 1 row | The ERP row for WEB carries `timezone = 'UTC'` and `opened_date = 2019-04-01`. `CONVENTIONS.md` says the website has neither. |
| `assert_order_line_cost_is_known` | 643 rows | 643 of 652 order lines have no product cost that applied at the order time (decision 1). |

## Teammates and the tasks each completed

The task list and its dependencies are in `reports/TEAM_PLAN.md`. This session had no shared
task-list tool, so that table was the task list. The lead updated it as teammates reported.

| Teammate | Tasks | Result in its own scratch database |
|---|---|---|
| lead | T01 shared macros and per-teammate targets; T09 full build; T10 this report | Full build as above |
| `crm` | T02 CRM (Customer Relationship Management) source, `stg_crm__accounts`, 5 singular tests | PASS=14 WARN=0 ERROR=0 |
| `ecom` | T03 e-commerce source, `stg_ecom__customers`, 5 singular tests | PASS=13 WARN=0 ERROR=0 |
| `erp` | T04 five ERP sources, five staging models, 8 singular tests; follow-up `source_order_date` | PASS=45 WARN=1 ERROR=0 |
| `pos` | T05 POS source, `stg_pos__transactions`, 5 singular tests including the late feed test | PASS=22 WARN=1 ERROR=0 |
| `marts` | T06 dimensions, T07 intermediate models, T08 the three reports and 8 singular tests | PASS=138 WARN=3 ERROR=0 |

`marts` was spawned only after `erp` (T04) and `pos` (T05) reported done.

## Files created

Lead:
- `macros/generate_surrogate_key.sql`
- `macros/audit_columns.sql`
- `macros/tests/test_unique_combination_of_columns.sql`
- `macros/tests/test_source_columns_match.sql`
- `reports/TEAM_PLAN.md`
- `reports/BUILD_REPORT.md`

`crm`:
- `models/staging/crm/_crm__sources.yml`, `_crm__models.yml`, `stg_crm__accounts.sql`
- `tests/crm/assert_crm_account_appears_once_per_snapshot.sql`
- `tests/crm/assert_crm_account_one_ingested_at_per_file.sql`
- `tests/crm/assert_stg_crm_account_deletion_only_when_absent.sql`
- `tests/crm/assert_stg_crm_account_every_snapshot_reconciles.sql`
- `tests/crm/assert_stg_crm_account_kept_rows_differ.sql`

`ecom`:
- `models/staging/ecom/_ecom__sources.yml`, `_ecom__models.yml`, `stg_ecom__customers.sql`
- `tests/ecom/assert_ecom_customer_id_once_per_snapshot.sql`
- `tests/ecom/assert_ecom_customer_one_ingested_at_per_file.sql`
- `tests/ecom/assert_stg_ecom__customers_deleted_only_when_absent.sql`
- `tests/ecom/assert_stg_ecom__customers_holds_no_unchanged_row.sql`
- `tests/ecom/assert_stg_ecom__customers_matches_every_snapshot.sql`

`erp`:
- `models/staging/erp/_erp__sources.yml`, `_erp__models.yml`
- `models/staging/erp/stg_erp__branches.sql`, `stg_erp__customers.sql`, `stg_erp__products.sql`,
  `stg_erp__order_headers.sql`, `stg_erp__order_lines.sql`
- `tests/erp/assert_line_amount_equals_quantity_times_unit_price.sql`
- `tests/erp/assert_no_order_after_customer_deleted.sql`
- `tests/erp/assert_order_change_within_fourteen_days.sql`
- `tests/erp/assert_order_has_lines.sql`
- `tests/erp/assert_order_total_reconciles.sql`
- `tests/erp/assert_physical_branch_has_timezone.sql`
- `tests/erp/assert_web_branch_has_no_city_timezone_or_opened_date.sql`
- `tests/erp/assert_web_branch_present.sql`

`pos`:
- `models/staging/pos/_pos__sources.yml`, `_pos__models.yml`, `stg_pos__transactions.sql`
- `tests/pos/assert_pos_branch_is_known_erp_branch.sql`
- `tests/pos/assert_pos_branch_sent_rows_each_night.sql`
- `tests/pos/assert_pos_has_no_website_rows.sql`
- `tests/pos/assert_pos_one_version_per_transaction.sql`
- `tests/pos/assert_pos_row_arrived_within_open_period.sql`

`marts`:
- `models/intermediate/_int__models.yml`, `int_order_headers_current.sql`,
  `int_order_lines_current.sql`, `int_order_lines_costed.sql`,
  `int_order_sales_by_branch_day.sql`, `int_pos_sales_by_branch_day.sql`
- `models/marts/_marts__models.yml`, `dim_branch.sql`, `dim_customer.sql`, `dim_product.sql`,
  `fct_order.sql`, `fct_order_line.sql`, `fct_daily_branch_sales.sql`
- `tests/marts/assert_daily_branch_sales_has_one_version_per_pos_transaction.sql`
- `tests/marts/assert_daily_branch_sales_margin_is_revenue_minus_cost.sql`
- `tests/marts/assert_daily_branch_sales_reconciles_to_inputs.sql`
- `tests/marts/assert_dimension_versions_are_well_formed.sql`
- `tests/marts/assert_each_order_counted_once.sql`
- `tests/marts/assert_no_deleted_order.sql`
- `tests/marts/assert_order_line_cost_is_known.sql`
- `tests/marts/assert_order_total_equals_sum_of_lines.sql`

## Files changed

- `profiles.yml` (lead). Added one scratch DuckDB target per teammate, writing to
  `target/team_<name>.duckdb`, because DuckDB lets only one process write to a file at a time.
  Set `TimeZone: UTC` on every target, including `dev`.
- `analytics.duckdb` was rebuilt by the final build. It is ignored by git (`*.duckdb`).

Not changed: `dbt_project.yml`, every file under `landing/`, every existing Markdown file.
Nothing was committed or pushed. Scratch databases and run artifacts are under `target/`, which
git ignores.

## Business decisions the build could not make

Each one is reported here and not filled in with an invented rule.

1. **Product cost, and every dimension attribute, before the ERP change feed began.** The feed
   starts on 20 July 2026, and orders go back to January 2026. The first `I` row of each
   product is stamped when the feed loaded it, not when that cost began. So the cost that
   applied on the date of most sales is unknown. As a result, cost and margin are null on 212 of
   227 daily rows, and 643 of 652 order lines are uncosted. The dimension keys on most orders
   are also null. Someone has to decide whether a first `I` row applies before its `change_ts`,
   or supply a cost history.
2. **Which time zone defines an order's business date.** `order_date` is the date the ERP wrote,
   in its own `-05:00` offset. It is marked provisional. The web branch has no time zone in
   `CONVENTIONS.md`, and the data gives it `UTC`.
3. **When a feed counts as late for CRM, e-commerce and ERP.** "By 4am" has no time zone, and the
   warehouse does not know when a file arrived. Only POS has a late feed test, and it checks
   per branch per nightly file, not against a clock. The ingestion team could supply arrival
   metadata, as `CONVENTIONS.md` notes.
4. **How a deleted ERP order or order line affects revenue.** Deleted rows are kept with
   `is_deleted`. Every total on that branch-day would be null, with a count column showing how
   many rows are affected. There are none today, and `assert_no_deleted_order` warns if one
   arrives.
5. **Which POS row counts when a `(branch_id, transaction_id)` repeats** (a correction, or a
   zero-amount void reusing the ID). Staging keeps every version. The daily totals would be null
   for that branch-day, and two tests warn. There are none today.
6. **Whether a zero-amount void or a refund counts in `transaction_count`.** Today every till row
   counts as one transaction, and there are no voids or refunds in the data.
7. **Whether a plain POS resend in a later file is the same row.** `received_at` is a column the
   till sends, so a resend with a new `received_at` is kept as a second version.
8. **Whether ERP `I` rows arriving more than 14 days after the order date break the period-close
   rule.** The first delivery loaded orders going back to January. `erp` tests only `U` and `D`
   rows against the window.
9. **What happens to a row that arrives after its period closed, and how a published number is
   held final.** The tests flag late arrivals. But every model is rebuilt in full, and nothing
   freezes a closed period. `is_period_closed` is a flag, not a lock.
10. **Customer matching across CRM, ERP and e-commerce.** `REQUIREMENTS.md` already records this
    as undecided. CRM and e-commerce are staged only, `dim_customer` holds ERP customers only,
    and no report joins across systems.
11. **Whether the ERP or `CONVENTIONS.md` is right about the web branch.** The data gives WEB an
    opening date and a time zone, and the conventions say it has neither.

## Rules and assumptions relied on that are not stated in the four documents

Build shape (lead):
- Sources read every file in the folder as text, matching columns by name (`union_by_name`),
  with the file name kept. Staging does all casting.
- Tests that detect incoming data breaking a convention, or an undecided rule, run at severity
  warn. Grain, key and accepted-values tests run at error. This extends the late feed sentence
  ("fails a test, not the job") to every data-contract test, because in `dbt build` an error
  test skips everything downstream.
- `inserted_ts` and `updated_ts` are both the build time, because every model is rebuilt in full.
- The DuckDB session time zone is UTC, so timestamps become the same text, and the same
  surrogate keys, on every machine.
- Surrogate keys are an MD5 (Message Digest 5) hash of the key columns, with nulls marked and
  values separated.
- A source timestamp whose standard name collides with an audit column takes a `source_`
  prefix (`source_updated_ts`).

Staging:
- `Id` is lower-cased to `id`. `uom` is renamed `unit_of_measure` (no abbreviations), and `sku`
  is kept.
- Business keys are text, except `line_number`, which is an integer.
- For CRM and e-commerce, a snapshot is one `_ingested_at` value. A deletion row is dated to the
  first snapshot a record is missing from, and takes that snapshot's file name (the first
  alphabetically, if several). A record that comes back is kept even if unchanged.
- E-commerce and CRM timestamps are read as the UTC (Coordinated Universal Time) values their
  `Z` suffix states.
- ERP validity uses `change_ts`, not `updated_on`.
- POS: the arrival date is the date in the file name, not `received_at`. A file name carries one
  night per system.
- POS: the website is the ERP branch with no city (`pos`). ERP tests identify physical branches as
  `branch_id <> 'WEB'` (`erp`).
- POS: a branch is expected to send rows once its `opened_date` is on or before the night, using
  its latest non-deleted ERP row. Every night between the first and last file is expected. A
  missing latest night cannot be seen.
- POS: identical rows are compared after casting, and the copy from the earliest file is kept.
- The fourteen-day window: a sale may arrive up to `sale_date + 14`. For ERP it is measured as
  elapsed time from `order_ts` to `change_ts`.
- CRM `Industry` and `AccountSource` have no accepted-values test, because no list is documented.

Marts:
- A dimension version covers `valid_from_ts` up to, not including, `valid_to_ts`. Nothing is
  back-filled before the first version.
- The current order or line is the row with the latest `change_ts`. A `D` row keeps its values
  with `is_deleted = true`.
- Every order status (`OPEN`, `SHIPPED`, `INVOICED`) counts as an order booked, and so as a sale
  in the daily report.
- Daily report rows exist only where a branch had a sale or an order. A branch-day with no
  activity has no row, not a zero row.
- A daily cost is published only when every order line that day has a known cost. Otherwise
  cost and margin are null, and the parts are published beside them.
- `period_close_date` is `sale_date + 14`. `is_period_closed` compares it with the build date.
- A POS refund is dated by its own sale time (none exist today).
- If the product version valid at order time is a `D` row, its cost is still used (none today).
- `fct_order.line_count` includes deleted lines. The order total reconciliation leaves deleted
  orders and lines out.

## Messages between teammates that changed a teammate's work

1. **`ecom` and `crm`, then lead to `ecom`: the file name on a deletion row.** `ecom` proposed six
   shared details to `crm`. `crm` agreed on five and asked `ecom` to match its rule on the sixth.
   Its rule stamps a deletion row with the file of the snapshot the record went missing from.
   `ecom`'s rule left the file name null. The lead confirmed `crm`'s rule to `ecom`. `ecom`
   changed `stg_ecom__customers` and its column description. It added `not_null` on
   `source_file_name` and two tests matching `crm`'s (`assert_ecom_customer_id_once_per_snapshot`,
   `assert_stg_ecom__customers_deleted_only_when_absent`). It went from 10 to 13 passing checks.
2. **`erp` to lead: surrogate keys depended on the machine's time zone.** The lead changed
   `profiles.yml` to set `TimeZone: UTC` on every target.
3. **Lead to `erp`: keep the order date the ERP recorded.** `erp` added `source_order_date` to
   `stg_erp__order_headers` and its YAML (with a `not_null` test). `marts` builds `order_date` from
   it.
4. **`marts` to lead: the five product updates change list price, not cost.** The lead corrected
   that line in `reports/TEAM_PLAN.md`.

Relays that informed work without changing it:
- `erp` and `pos` could not message `marts` before it was spawned. The lead passed their model
  names, grains and column lists in the `marts` brief, and passed on the new `source_order_date`.
- `erp` sent `pos` the `stg_erp__branches` columns. They matched what `pos` had already read from
  the model file, so nothing changed.

Teammates could not address the lead as "main" and used "team-lead" instead. One message from
`ecom` to `crm` failed on a temporary error and was resent.

## Verification commands the lead ran

- Data profiling queries over `landing/` with DuckDB, read only, before planning.
- `../.venv/bin/dbt debug --target erp` and `../.venv/bin/dbt parse` after adding the targets.
- A throwaway dbt project in the session scratchpad to check the external source syntax and
  the `TimeZone` setting.
- `../.venv/bin/dbt build` for the complete project, with the result line above.
- Read-only queries on `analytics.duckdb` to confirm the report columns and totals.
