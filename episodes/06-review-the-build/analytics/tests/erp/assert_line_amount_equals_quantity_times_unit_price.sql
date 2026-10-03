-- Every order line row carries line_amount equal to quantity times unit_price_amount.
-- Checked on every row of the change feed, not only the latest version.
-- Returns one row per line version where the numbers differ.

{{ config(severity = 'warn') }}

select
    order_number,
    line_number,
    change_ts,
    quantity,
    unit_price_amount,
    line_amount,
    quantity * unit_price_amount as expected_line_amount
from {{ ref('stg_erp__order_lines') }}
where line_amount <> quantity * unit_price_amount
