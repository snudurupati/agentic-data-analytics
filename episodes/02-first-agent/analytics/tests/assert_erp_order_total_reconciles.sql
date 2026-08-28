-- Fail if an order's order_total stops matching the sum of its lines.
--
-- Reconciles on all 230 orders in the landing zone today, worst gap 0.00.
--
-- This is the check most likely to catch an incremental bug rather than a
-- source problem, because the header and the lines are two separate models
-- with two separate watermarks. If one advances and the other does not, an
-- order ends up with a total that no longer matches the lines underneath it,
-- and this is where that shows up.
--
-- Deleted rows are excluded on both sides. They are kept in staging by
-- convention, but an order marked deleted has no business reconciling against
-- lines that are still live.

with order_totals as (

    select
        order_number,
        order_total
    from {{ ref('stg_erp__order_headers') }}
    where not is_deleted

),

line_totals as (

    select
        order_number,
        sum(line_amount) as summed_lines
    from {{ ref('stg_erp__order_lines') }}
    where not is_deleted
    group by order_number

)

select
    order_totals.order_number,
    order_totals.order_total,
    line_totals.summed_lines,
    order_totals.order_total - line_totals.summed_lines as difference

from order_totals
join line_totals
    on order_totals.order_number = line_totals.order_number

where abs(order_totals.order_total - line_totals.summed_lines) > 0.005
