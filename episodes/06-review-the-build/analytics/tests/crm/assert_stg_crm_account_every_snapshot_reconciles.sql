-- Structural check on stg_crm__accounts.
-- For every account in every source snapshot, the latest staging row at or before that
-- snapshot must be a row that is not deleted and carries the same values the source sent.
-- Returns every source row the staging model does not reproduce.

with source_rows as (

    select
        Id as id,
        Name as name,
        Industry as industry,
        BillingCity as billing_city,
        BillingState as billing_state,
        AccountSource as account_source,
        Owner as owner,
        cast(LastModifiedDate as timestamptz) as last_modified_ts,
        cast(_ingested_at as timestamptz) as ingested_ts
    from {{ source('crm', 'account') }}

),

held_row as (

    select
        source_rows.id,
        source_rows.ingested_ts as snapshot_ts,
        staged.name,
        staged.industry,
        staged.billing_city,
        staged.billing_state,
        staged.account_source,
        staged.owner,
        staged.last_modified_ts,
        staged.is_deleted,
        row_number() over (
            partition by source_rows.id, source_rows.ingested_ts
            order by staged.ingested_ts desc
        ) as recency
    from source_rows
    inner join {{ ref('stg_crm__accounts') }} as staged
        on staged.id = source_rows.id
       and staged.ingested_ts <= source_rows.ingested_ts

)

select source_rows.id, source_rows.ingested_ts
from source_rows
left join held_row
    on held_row.id = source_rows.id
   and held_row.snapshot_ts = source_rows.ingested_ts
   and held_row.recency = 1
where held_row.id is null
   or held_row.is_deleted
   or held_row.name is distinct from source_rows.name
   or held_row.industry is distinct from source_rows.industry
   or held_row.billing_city is distinct from source_rows.billing_city
   or held_row.billing_state is distinct from source_rows.billing_state
   or held_row.account_source is distinct from source_rows.account_source
   or held_row.owner is distinct from source_rows.owner
   or held_row.last_modified_ts is distinct from source_rows.last_modified_ts
