-- Fail if stg_erp__order_lines has more than one row per order line.
--
-- The grain is order_number and line_number together. line_number restarts at
-- 1 on every order, so neither column is a key on its own and the built-in
-- `unique` test cannot express this.
--
-- This is the check that the incremental collapse actually works. If the
-- change feed ever delivers two changes for the same line at the same
-- change_ts, or if the watermark lets a batch through twice without the
-- delete+insert replacing what was there, it shows up here as a duplicate.

select
    order_number,
    line_number,
    count(*) as rows_at_this_grain

from {{ ref('stg_erp__order_lines') }}

group by order_number, line_number
having count(*) > 1
