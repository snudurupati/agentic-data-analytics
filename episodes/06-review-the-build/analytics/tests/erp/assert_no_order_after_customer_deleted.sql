-- No order is placed by a customer after that customer was deleted (CONVENTIONS.md: deleting a
-- customer stops new activity).
-- Compares each order's order_ts with the change_ts of the customer's delete rows.
-- Returns one row per order version placed after its customer's delete.

{{ config(severity = 'warn') }}

select
    order_headers.order_number,
    order_headers.change_ts,
    order_headers.order_ts,
    order_headers.customer_number,
    customer_deletes.change_ts as customer_deleted_ts
from {{ ref('stg_erp__order_headers') }} as order_headers
inner join {{ ref('stg_erp__customers') }} as customer_deletes
    on order_headers.customer_number = customer_deletes.customer_number
   and customer_deletes.is_deleted
where order_headers.order_ts > customer_deletes.change_ts
