-- The WEB branch has no city, no timezone and no opening date, because there is no building
-- (CONVENTIONS.md, point of sale specs).
-- Checked on every version of the WEB branch.
-- Returns one row per WEB branch version that carries any of the three.

{{ config(severity = 'warn') }}

select
    branch_id,
    change_ts,
    city,
    timezone,
    opened_date
from {{ ref('stg_erp__branches') }}
where branch_id = 'WEB'
  and (city is not null or timezone is not null or opened_date is not null)
