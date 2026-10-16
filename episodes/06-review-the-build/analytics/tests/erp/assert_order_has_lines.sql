-- Every order header has at least one order line (REQUIREMENTS.md: an order has one header and
-- one or more lines). Checked against any version of the lines, deleted or not.
-- Returns one row per order number with no line at all.

{{ config(severity = 'warn') }}

select distinct order_headers.order_number
from {{ ref('stg_erp__order_headers') }} as order_headers
where not exists (
    select 1
    from {{ ref('stg_erp__order_lines') }} as order_lines
    where order_lines.order_number = order_headers.order_number
)
