-- Order line values report (REQUIREMENTS.md). One row per ERP (Enterprise Resource Planning)
-- order line.
-- Grain: one row per order_number per line_number, using the latest version of each line.
--
-- unit_cost_amount is the product cost that applied when the order was placed, and
-- cost_amount is quantity times that cost. Both are null when the cost at that time is
-- unknown (see int_order_lines_costed). product_key points at the product version valid at
-- order_ts, and is null when none was.
--
-- order_date is provisional, for the same reason as in fct_order.
-- A deleted line is kept, with is_deleted true.

with costed_lines as (

    select * from {{ ref('int_order_lines_costed') }}

)

select
    order_line_key,
    order_number,
    line_number,
    source_order_date as order_date,
    order_ts,
    branch_id,
    customer_number,
    product_id,
    product_key,
    quantity,
    unit_price_amount,
    line_amount,
    unit_cost_amount,
    cost_amount,
    is_deleted,
    {{ audit_columns() }}
from costed_lines
