-- Incoming data check on the CRM (Customer Relationship Management) source.
-- A full dump sends each account once. Returns every account Id that appears more than once
-- in a single snapshot (one value of _ingested_at).
{{ config(severity = 'warn') }}

select
    Id,
    _ingested_at,
    count(*) as row_count
from {{ source('crm', 'account') }}
group by Id, _ingested_at
having count(*) > 1
