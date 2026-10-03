-- ERP (Enterprise Resource Planning) orders summed per branch per order date.
-- Grain: one row per branch_id per source_order_date, only where the branch booked at least
-- one order that day.
--
-- Revenue comes from the order header total, so each order is counted once. Item count and
-- cost come from the order lines. A line whose cost is unknown (see int_order_lines_costed)
-- is counted in uncosted_line_count and left out of known_cost_amount.
-- Deleted orders and lines are included and counted, because how a deletion affects revenue
-- has not been decided.

with order_headers as (

    select * from {{ ref('int_order_headers_current') }}

),

order_lines as (

    select * from {{ ref('int_order_lines_costed') }}

),

orders_per_day as (

    select
        branch_id,
        source_order_date,
        sum(order_total_amount)               as order_total_amount,
        count(*)                              as order_count,
        count(*) filter (where is_deleted)    as deleted_order_count
    from order_headers
    group by branch_id, source_order_date

),

lines_per_day as (

    select
        branch_id,
        source_order_date,
        sum(quantity)                             as item_count,
        sum(cost_amount)                          as known_cost_amount,
        count(*)                                  as line_count,
        count(*) filter (where is_cost_unknown)   as uncosted_line_count,
        count(*) filter (where is_deleted)        as deleted_line_count
    from order_lines
    group by branch_id, source_order_date

),

combined as (

    select
        orders_per_day.branch_id,
        orders_per_day.source_order_date,
        orders_per_day.order_total_amount,
        orders_per_day.order_count,
        orders_per_day.deleted_order_count,
        coalesce(lines_per_day.item_count, 0)            as item_count,
        coalesce(lines_per_day.known_cost_amount, 0)     as known_cost_amount,
        coalesce(lines_per_day.line_count, 0)            as line_count,
        coalesce(lines_per_day.uncosted_line_count, 0)   as uncosted_line_count,
        coalesce(lines_per_day.deleted_line_count, 0)    as deleted_line_count
    from orders_per_day
    left join lines_per_day
        on orders_per_day.branch_id = lines_per_day.branch_id
        and orders_per_day.source_order_date = lines_per_day.source_order_date

)

select
    {{ generate_surrogate_key(['branch_id', 'source_order_date']) }} as order_branch_day_key,
    *,
    {{ audit_columns() }}
from combined
