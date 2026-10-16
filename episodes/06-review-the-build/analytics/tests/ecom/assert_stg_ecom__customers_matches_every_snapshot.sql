/*
    Rebuilding each snapshot from stg_ecom__customers gives back exactly what the source delivered.

    For every snapshot, take each customer's latest staging row at or before that snapshot. The
    customers whose latest row is not deleted, with their values, must equal the customers and
    values in the source for that snapshot. This checks that no change was dropped, no customer
    was lost (CONVENTIONS.md: we never delete), and no customer was marked deleted while still
    being delivered.

    Returns one row per difference. Severity error: a difference is a fault in the model.
*/
{{ config(severity = 'error') }}

with source_snapshots as (

    select
        customer_id,
        company_name,
        email_domain,
        contact_email,
        country,
        cast(created_at as timestamptz) as source_created_ts,
        cast(updated_at as timestamptz) as source_updated_ts,
        cast(_ingested_at as timestamptz) as ingested_ts
    from {{ source('ecom', 'customer') }}

),

snapshot_times as (

    select distinct ingested_ts from source_snapshots

),

-- Each customer's latest staging row at or before each snapshot.
rebuilt_from_staging as (

    select
        staging.customer_id,
        staging.company_name,
        staging.email_domain,
        staging.contact_email,
        staging.country,
        staging.source_created_ts,
        staging.source_updated_ts,
        snapshot_times.ingested_ts,
        staging.is_deleted
    from snapshot_times
    inner join {{ ref('stg_ecom__customers') }} as staging
        on staging.ingested_ts <= snapshot_times.ingested_ts
    qualify row_number() over (
        partition by staging.customer_id, snapshot_times.ingested_ts
        order by staging.ingested_ts desc
    ) = 1

),

rebuilt_present as (

    select * exclude (is_deleted)
    from rebuilt_from_staging
    where not is_deleted

)

select 'in source, not rebuilt from staging' as difference, *
from (select * from source_snapshots except select * from rebuilt_present)

union all

select 'rebuilt from staging, not in source' as difference, *
from (select * from rebuilt_present except select * from source_snapshots)
