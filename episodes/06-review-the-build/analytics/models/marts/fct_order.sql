-- Order values report (REQUIREMENTS.md). One row per ERP (Enterprise Resource Planning) order.
-- Grain: one row per order_number, using the latest version of the order header.
--
-- order_date is provisional. It is the calendar date as the ERP recorded it, in the ERP's own
-- time zone offset (source_order_date). Which time zone defines the business date of an order
-- is an open business decision.
--
-- branch_key and customer_key point at the dimension version that was valid at order_ts.
-- When no version was valid then (the order is older than the change feed), the key is null.
-- Nothing is back-filled.
--
-- A deleted order is kept, with is_deleted true.

with order_headers as (

    select * from {{ ref('int_order_headers_current') }}

),

order_lines as (

    select * from {{ ref('int_order_lines_current') }}

),

branches as (

    select * from {{ ref('dim_branch') }}

),

customers as (

    select * from {{ ref('dim_customer') }}

),

line_counts as (

    select
        order_number,
        count(*) as line_count
    from order_lines
    group by order_number

)

select
    order_headers.order_key,
    order_headers.order_number,
    order_headers.source_order_date as order_date,
    order_headers.order_ts,
    order_headers.branch_id,
    branches.branch_key,
    order_headers.customer_number,
    customers.customer_key,
    order_headers.status,
    order_headers.currency,
    order_headers.order_total_amount,
    coalesce(line_counts.line_count, 0) as line_count,
    order_headers.is_deleted,
    {{ audit_columns() }}
from order_headers
left join line_counts
    on order_headers.order_number = line_counts.order_number
left join branches
    on order_headers.branch_id = branches.branch_id
    and branches.valid_from_ts <= order_headers.order_ts
    and (branches.valid_to_ts is null or order_headers.order_ts < branches.valid_to_ts)
left join customers
    on order_headers.customer_number = customers.customer_number
    and customers.valid_from_ts <= order_headers.order_ts
    and (customers.valid_to_ts is null or order_headers.order_ts < customers.valid_to_ts)
