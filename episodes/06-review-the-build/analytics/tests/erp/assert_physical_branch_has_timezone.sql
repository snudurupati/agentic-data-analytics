-- Every physical branch has a time zone that DuckDB recognises. Till times are branch local
-- times, and the branch time zone is how they are placed on a clock (CONVENTIONS.md).
-- A physical branch is any branch other than WEB. Deleted versions are left out.
-- Returns one row per branch version with a missing or unrecognised time zone.

{{ config(severity = 'warn') }}

select
    branch_id,
    change_ts,
    timezone
from {{ ref('stg_erp__branches') }}
where branch_id <> 'WEB'
  and not is_deleted
  and (
      timezone is null
      or timezone not in (select name from pg_timezone_names())
  )
