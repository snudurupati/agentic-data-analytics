/*
    assert_order_line_cost_is_known

    Checks: every order line in fct_order_line has a known cost. Returns one row per line whose
    cost is unknown, so the warning count is the number of uncosted lines.

    Why: REQUIREMENTS.md says a report uses the cost that applied on the date of the sale. The
    ERP (Enterprise Resource Planning) change feed began on 20 July 2026, and the cost of a
    product before its first change is not recorded anywhere. Every order placed before that
    has no known cost. This is the pre-change-feed cost gap. fct_daily_branch_sales leaves
    cost_amount and margin_amount null for any branch-day holding one of these lines.
    Filling the gap needs a business decision or a cost history from before the feed began.
    Severity warn: it flags incoming data that needs a business decision. It must not stop the
    build.
*/

{{ config(severity = 'warn') }}

select
    order_number,
    line_number,
    product_id,
    order_date,
    order_ts,
    branch_id
from {{ ref('fct_order_line') }}
where cost_amount is null
