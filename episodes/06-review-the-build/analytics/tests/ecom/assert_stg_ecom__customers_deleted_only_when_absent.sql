/*
    A deleted row in stg_ecom__customers appears only where the customer is absent from that
    snapshot and was present in the snapshot before it.

    CONVENTIONS.md: in a snapshot feed, a record only stops appearing when it has been deleted.
    This checks the model marks a customer deleted in exactly that case.

    Returns one row per deleted row that breaks the rule. Severity error: a break is a fault in
    the model.
*/
{{ config(severity = 'error') }}

with source_rows as (

    select
        customer_id,
        cast(_ingested_at as timestamptz) as ingested_ts
    from {{ source('ecom', 'customer') }}

),

snapshots as (

    select
        ingested_ts,
        lag(ingested_ts) over (order by ingested_ts) as previous_ingested_ts
    from (select distinct ingested_ts from source_rows) as distinct_snapshots

),

deleted_rows as (

    select customer_id, ingested_ts
    from {{ ref('stg_ecom__customers') }}
    where is_deleted

)

select
    deleted_rows.customer_id,
    deleted_rows.ingested_ts
from deleted_rows
left join snapshots
    on deleted_rows.ingested_ts = snapshots.ingested_ts
where snapshots.ingested_ts is null
   or exists (
       select 1 from source_rows
       where source_rows.customer_id = deleted_rows.customer_id
         and source_rows.ingested_ts = deleted_rows.ingested_ts
   )
   or not exists (
       select 1 from source_rows
       where source_rows.customer_id = deleted_rows.customer_id
         and source_rows.ingested_ts = snapshots.previous_ingested_ts
   )
