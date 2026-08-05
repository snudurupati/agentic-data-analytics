-- Fail if an order line's line_amount stops equalling quantity * unit_price.
--
-- This reconciles exactly on all 652 lines in the landing zone today. That is
-- the reason to pin it rather than the reason to skip it: a fact recorded in
-- prose quietly becomes a lie, while a test reports the day it stops holding.
--
-- The tolerance is half a cent, so a rounding difference in the ERP's own
-- arithmetic does not turn the build red, but a genuine discrepancy does.

select
    order_number,
    line_number,
    quantity,
    unit_price,
    line_amount,
    quantity * unit_price               as expected_line_amount,
    line_amount - quantity * unit_price as difference

from {{ ref('stg_erp__order_lines') }}

where abs(line_amount - quantity * unit_price) > 0.005
