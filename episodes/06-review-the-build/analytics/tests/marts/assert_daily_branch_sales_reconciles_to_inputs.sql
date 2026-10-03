/*
    assert_daily_branch_sales_reconciles_to_inputs

    Checks: every branch-day in fct_daily_branch_sales matches the inputs it was built from,
    worked out again here by a separate route:
      - the POS (point of sale) parts match stg_pos__transactions summed per branch per sale_date;
      - the order parts match fct_order and fct_order_line summed per branch per order_date;
      - each published total equals the sum of its parts, wherever the total is not null;
      - no branch-day in the inputs is missing from the report, and the report has no extra one.
    Returns one row per branch-day that does not match.

    Why: STANDARDS.md says two numbers that should reconcile get a test.
    Severity error: a mismatch means the report is built wrong, not that the data is unusual.
*/

with pos_expected as (

    select
        branch_id,
        sale_date,
        sum(sale_amount)  as pos_revenue_amount,
        sum(cost_amount)  as pos_cost_amount,
        count(*)          as pos_transaction_count,
        sum(item_count)   as pos_item_count
    from {{ ref('stg_pos__transactions') }}
    group by branch_id, sale_date

),

orders_expected as (

    select
        branch_id,
        order_date               as sale_date,
        sum(order_total_amount)  as order_revenue_amount,
        count(*)                 as order_count
    from {{ ref('fct_order') }}
    group by branch_id, order_date

),

lines_expected as (

    select
        branch_id,
        order_date                                  as sale_date,
        sum(quantity)                               as order_item_count,
        coalesce(sum(cost_amount), 0)               as known_order_cost_amount,
        count(*)                                    as order_line_count,
        count(*) filter (where cost_amount is null) as uncosted_order_line_count
    from {{ ref('fct_order_line') }}
    group by branch_id, order_date

),

branch_days as (

    select branch_id, sale_date from pos_expected
    union
    select branch_id, sale_date from orders_expected

),

expected as (

    select
        branch_days.branch_id,
        branch_days.sale_date,
        coalesce(pos_expected.pos_revenue_amount, 0)          as pos_revenue_amount,
        coalesce(pos_expected.pos_cost_amount, 0)             as pos_cost_amount,
        coalesce(pos_expected.pos_transaction_count, 0)       as pos_transaction_count,
        coalesce(pos_expected.pos_item_count, 0)              as pos_item_count,
        coalesce(orders_expected.order_revenue_amount, 0)     as order_revenue_amount,
        coalesce(orders_expected.order_count, 0)              as order_count,
        coalesce(lines_expected.order_item_count, 0)          as order_item_count,
        coalesce(lines_expected.known_order_cost_amount, 0)   as known_order_cost_amount,
        coalesce(lines_expected.order_line_count, 0)          as order_line_count,
        coalesce(lines_expected.uncosted_order_line_count, 0) as uncosted_order_line_count
    from branch_days
    left join pos_expected
        on branch_days.branch_id = pos_expected.branch_id
        and branch_days.sale_date = pos_expected.sale_date
    left join orders_expected
        on branch_days.branch_id = orders_expected.branch_id
        and branch_days.sale_date = orders_expected.sale_date
    left join lines_expected
        on branch_days.branch_id = lines_expected.branch_id
        and branch_days.sale_date = lines_expected.sale_date

),

actual as (

    select * from {{ ref('fct_daily_branch_sales') }}

)

select
    coalesce(expected.branch_id, actual.branch_id) as branch_id,
    coalesce(expected.sale_date, actual.sale_date) as sale_date,
    case
        when actual.branch_id is null then 'branch-day missing from report'
        when expected.branch_id is null then 'branch-day in report but not in inputs'
        else 'a part or a total does not match'
    end as problem
from expected
full outer join actual
    on expected.branch_id = actual.branch_id
    and expected.sale_date = actual.sale_date
where actual.branch_id is null
   or expected.branch_id is null
   -- The parts match the inputs.
   or actual.pos_revenue_amount        <> expected.pos_revenue_amount
   or actual.pos_cost_amount           <> expected.pos_cost_amount
   or actual.pos_transaction_count     <> expected.pos_transaction_count
   or actual.pos_item_count            <> expected.pos_item_count
   or actual.order_revenue_amount      <> expected.order_revenue_amount
   or actual.order_count               <> expected.order_count
   or actual.order_item_count          <> expected.order_item_count
   or actual.known_order_cost_amount   <> expected.known_order_cost_amount
   or actual.order_line_count          <> expected.order_line_count
   or actual.uncosted_order_line_count <> expected.uncosted_order_line_count
   -- Each total, where published, is the sum of its parts.
   or actual.revenue_amount    <> actual.pos_revenue_amount + actual.order_revenue_amount
   or actual.transaction_count <> actual.pos_transaction_count + actual.order_count
   or actual.item_count        <> actual.pos_item_count + actual.order_item_count
   or actual.cost_amount       <> actual.pos_cost_amount + actual.known_order_cost_amount
   -- A cost is never published while an order line's cost is unknown.
   or (actual.cost_amount is not null and actual.uncosted_order_line_count > 0)
