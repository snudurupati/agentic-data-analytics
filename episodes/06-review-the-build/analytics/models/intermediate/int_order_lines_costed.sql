-- Each current ERP (Enterprise Resource Planning) order line with the unit cost that applied
-- when the order was placed.
-- Grain: one row per order_number per line_number.
--
-- REQUIREMENTS.md says a report uses the cost that applied on the date of the sale. The cost
-- comes from the dim_product version that was valid at the order's order_ts:
--     valid_from_ts <= order_ts < valid_to_ts (or no valid_to_ts, for the latest version).
--
-- When no product version was valid at order_ts, unit_cost_amount and cost_amount are null.
-- This happens for every order placed before the product's first change_ts, because the
-- change feed does not say what the cost was before it began. A later cost is never used
-- for an earlier sale.
--
-- The line also carries the order's date, branch and customer from its header, so that the
-- reports do not have to join the header again.

with order_lines as (

    select * from {{ ref('int_order_lines_current') }}

),

order_headers as (

    select * from {{ ref('int_order_headers_current') }}

),

products as (

    select * from {{ ref('dim_product') }}

),

lines_with_header as (

    select
        order_lines.order_number,
        order_lines.line_number,
        order_lines.product_id,
        order_lines.quantity,
        order_lines.unit_price_amount,
        order_lines.line_amount,
        order_lines.is_deleted,
        order_headers.order_ts,
        order_headers.source_order_date,
        order_headers.branch_id,
        order_headers.customer_number
    from order_lines
    left join order_headers
        on order_lines.order_number = order_headers.order_number

),

costed as (

    select
        lines_with_header.*,
        products.product_key,
        products.unit_cost_amount,
        lines_with_header.quantity * products.unit_cost_amount as cost_amount
    from lines_with_header
    left join products
        on lines_with_header.product_id = products.product_id
        and products.valid_from_ts <= lines_with_header.order_ts
        and (products.valid_to_ts is null or lines_with_header.order_ts < products.valid_to_ts)

)

select
    {{ generate_surrogate_key(['order_number', 'line_number']) }} as order_line_key,
    order_number,
    line_number,
    product_id,
    product_key,
    quantity,
    unit_price_amount,
    line_amount,
    unit_cost_amount,
    cost_amount,
    unit_cost_amount is null as is_cost_unknown,
    order_ts,
    source_order_date,
    branch_id,
    customer_number,
    is_deleted,
    {{ audit_columns() }}
from costed
