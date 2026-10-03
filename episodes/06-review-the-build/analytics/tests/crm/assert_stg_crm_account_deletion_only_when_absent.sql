-- Structural check on stg_crm__accounts.
-- A deletion row is added only when the account is absent from the source in that snapshot
-- and present in the snapshot immediately before it. Returns every deletion row that breaks
-- either condition.

with snapshots as (

    select
        cast(_ingested_at as timestamptz) as ingested_ts,
        lag(cast(_ingested_at as timestamptz)) over (order by cast(_ingested_at as timestamptz)) as previous_ingested_ts
    from {{ source('crm', 'account') }}
    group by _ingested_at

),

source_presence as (

    select distinct
        Id as id,
        cast(_ingested_at as timestamptz) as ingested_ts
    from {{ source('crm', 'account') }}

)

select deletion.id, deletion.ingested_ts
from {{ ref('stg_crm__accounts') }} as deletion
inner join snapshots
    on deletion.ingested_ts = snapshots.ingested_ts
where deletion.is_deleted
  and (
        -- the account is in the source for this snapshot
        exists (
            select 1 from source_presence
            where source_presence.id = deletion.id
              and source_presence.ingested_ts = deletion.ingested_ts
        )
        -- or the account is not in the source for the snapshot before
        or not exists (
            select 1 from source_presence
            where source_presence.id = deletion.id
              and source_presence.ingested_ts = snapshots.previous_ingested_ts
        )
  )
