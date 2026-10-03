/*
    assert_daily_branch_sales_margin_is_revenue_minus_cost

    Checks: in fct_daily_branch_sales, margin_amount equals revenue_amount minus cost_amount
    wherever cost_amount is not null, and margin_amount is null wherever cost_amount is null.
    Returns one row per branch-day that breaks this.

    Why: REQUIREMENTS.md defines margin as revenue minus cost.
    Severity error: a mismatch means the report is built wrong.
*/

select
    branch_id,
    sale_date,
    revenue_amount,
    cost_amount,
    margin_amount
from {{ ref('fct_daily_branch_sales') }}
where (cost_amount is not null and margin_amount is distinct from revenue_amount - cost_amount)
   or (cost_amount is null and margin_amount is not null)
