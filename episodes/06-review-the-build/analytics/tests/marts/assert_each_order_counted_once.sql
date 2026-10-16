/*
    assert_each_order_counted_once

    Checks: across fct_daily_branch_sales, the orders counted and the order revenue add up to
    exactly the orders in fct_order, no more and no fewer. Returns one row when they differ.

    Why: REQUIREMENTS.md says a report states the value of an order once for each order.
    fct_order is one row per order_number (its uniqueness test checks that), so matching its
    totals means no order was dropped or counted twice in the daily report.
    Severity error: a mismatch means the report is built wrong.
*/

with in_daily_report as (

    select
        sum(order_count)          as order_count,
        sum(order_revenue_amount) as order_revenue_amount
    from {{ ref('fct_daily_branch_sales') }}

),

in_order_report as (

    select
        count(*)                as order_count,
        sum(order_total_amount) as order_revenue_amount
    from {{ ref('fct_order') }}

)

select
    in_daily_report.order_count          as daily_report_order_count,
    in_order_report.order_count          as order_report_order_count,
    in_daily_report.order_revenue_amount as daily_report_order_revenue_amount,
    in_order_report.order_revenue_amount as order_report_order_revenue_amount
from in_daily_report
cross join in_order_report
where in_daily_report.order_count is distinct from in_order_report.order_count
   or in_daily_report.order_revenue_amount is distinct from in_order_report.order_revenue_amount
