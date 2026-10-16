/*
    Each e-commerce customer file carries exactly one _ingested_at value, and no row is missing it.

    CONVENTIONS.md: the ingestion system stamps every row with _ingested_at, one value per sync,
    not per row. stg_ecom__customers treats one _ingested_at value as one snapshot, so a file
    with several values, or with blanks, would be split into the wrong snapshots.

    Returns one row per file that breaks the rule. Severity warn: this is incoming data breaking
    a convention, not a fault in the build.
*/
{{ config(severity = 'warn') }}

select
    filename,
    count(distinct _ingested_at) as ingested_at_value_count,
    count(*) filter (where _ingested_at is null) as rows_without_ingested_at
from {{ source('ecom', 'customer') }}
group by filename
having count(distinct _ingested_at) <> 1
    or count(*) filter (where _ingested_at is null) > 0
