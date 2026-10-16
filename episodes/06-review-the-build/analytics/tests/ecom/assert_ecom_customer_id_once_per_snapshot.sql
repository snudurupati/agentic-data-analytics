/*
    Each customer_id appears at most once in each e-commerce snapshot.

    A full table dump sends each customer once per sync. A customer sent twice in one snapshot
    would give stg_ecom__customers two rows for the same customer and snapshot, and its grain
    test would fail.

    Returns one row per repeated customer_id and snapshot. Severity warn: this is incoming data
    breaking the shape of the feed, not a fault in the build.
*/
{{ config(severity = 'warn') }}

select
    customer_id,
    _ingested_at,
    count(*) as row_count
from {{ source('ecom', 'customer') }}
group by customer_id, _ingested_at
having count(*) > 1
