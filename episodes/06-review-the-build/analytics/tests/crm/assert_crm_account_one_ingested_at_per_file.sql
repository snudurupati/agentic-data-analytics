-- Incoming data check on the CRM (Customer Relationship Management) source.
-- CONVENTIONS.md: the ingestion system stamps _ingested_at once per sync, not per row.
-- Returns every file that carries more than one _ingested_at value, or a missing one.
{{ config(severity = 'warn') }}

select
    filename,
    count(distinct _ingested_at) as ingested_at_value_count,
    count(*) - count(_ingested_at) as missing_ingested_at_count
from {{ source('crm', 'account') }}
group by filename
having count(distinct _ingested_at) != 1
    or count(*) != count(_ingested_at)
