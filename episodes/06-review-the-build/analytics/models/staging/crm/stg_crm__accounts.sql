{#
    Staging for the CRM (Customer Relationship Management) account table from Salesforce.

    The feed is a full table dump: every night the whole table arrives again. This model keeps
    a row for an account in a snapshot only when:
      - it is the first time the account appears,
      - any column Salesforce sent differs from the row held before it, or
      - the account comes back after being marked deleted.
    When an account present in one snapshot is missing from the next snapshot, the model adds a
    row in that next snapshot with is_deleted = true, carrying the last values held.

    A snapshot is one value of _ingested_at. Columns stamped by the ingestion system
    (_ingested_at) or added by the file read (filename) are never compared.

    Grain: one row per account (id) per snapshot (ingested_ts) in which it changed.
#}

with

-- Step 1: read the source, rename to lower snake case and cast to real types.
-- Id is the Salesforce business key. It keeps its source name, lower-cased to id.
source_rows as (

    select
        Id                                      as id,
        Name                                    as name,
        Industry                                as industry,
        BillingCity                             as billing_city,
        BillingState                            as billing_state,
        AccountSource                           as account_source,
        Owner                                   as owner,
        cast(LastModifiedDate as timestamptz)   as last_modified_ts,
        cast(_ingested_at as timestamptz)       as ingested_ts,
        filename                                as source_file_name
    from {{ source('crm', 'account') }}

),

-- Step 2: list the snapshots in order, one row per value of ingested_ts, each with the
-- snapshot that follows it. The last snapshot has no next snapshot.
-- If one snapshot were spread over several files, the first file name (alphabetically) stands
-- for the snapshot.
snapshots as (

    select
        ingested_ts,
        min(source_file_name)                       as source_file_name,
        lead(ingested_ts) over (order by ingested_ts) as next_ingested_ts
    from source_rows
    group by ingested_ts

),

-- Step 3: find each account that is present in a snapshot and absent from the next one.
-- Each becomes a deletion row dated to that next snapshot, carrying the values it held
-- in the last snapshot where it appeared.
deletion_rows as (

    select
        present.id,
        present.name,
        present.industry,
        present.billing_city,
        present.billing_state,
        present.account_source,
        present.owner,
        present.last_modified_ts,
        next_snapshot.ingested_ts       as ingested_ts,
        next_snapshot.source_file_name  as source_file_name,
        true                            as is_deleted
    from source_rows as present
    inner join snapshots as this_snapshot
        on present.ingested_ts = this_snapshot.ingested_ts
    inner join snapshots as next_snapshot
        on this_snapshot.next_ingested_ts = next_snapshot.ingested_ts
    where not exists (
        select 1
        from source_rows as later
        where later.id = present.id
          and later.ingested_ts = next_snapshot.ingested_ts
    )

),

-- Step 4: put the rows the source sent and the deletion rows into one timeline per account.
timeline as (

    select
        id,
        name,
        industry,
        billing_city,
        billing_state,
        account_source,
        owner,
        last_modified_ts,
        ingested_ts,
        source_file_name,
        false as is_deleted
    from source_rows

    union all

    select
        id,
        name,
        industry,
        billing_city,
        billing_state,
        account_source,
        owner,
        last_modified_ts,
        ingested_ts,
        source_file_name,
        is_deleted
    from deletion_rows

),

-- Step 5: next to each row, place the row before it in the same account's timeline.
-- The source-sent columns are combined into one hash so a single comparison tells whether
-- anything Salesforce sent has changed.
compared as (

    select
        *,
        {{ generate_surrogate_key([
            'name', 'industry', 'billing_city', 'billing_state',
            'account_source', 'owner', 'last_modified_ts'
        ]) }} as source_values_hash
    from timeline

),

with_previous as (

    select
        *,
        lag(source_values_hash) over (partition by id order by ingested_ts) as previous_source_values_hash,
        lag(is_deleted)         over (partition by id order by ingested_ts) as previous_is_deleted
    from compared

),

-- Step 6: keep a row when it is the first for the account, when it is a deletion row, when
-- the row before it was a deletion row (the account came back), or when any source-sent
-- value differs from the row before it. A row identical to the one before it is dropped,
-- so the row before a kept row is always the row held before it.
kept as (

    select *
    from with_previous
    where previous_source_values_hash is null
       or is_deleted
       or previous_is_deleted
       or source_values_hash != previous_source_values_hash

)

-- Step 7: add the staging surrogate key and the audit columns.
select
    {{ generate_surrogate_key(['id', 'ingested_ts']) }} as stg_account_key,
    id,
    name,
    industry,
    billing_city,
    billing_state,
    account_source,
    owner,
    last_modified_ts,
    is_deleted,
    ingested_ts,
    source_file_name,
    {{ audit_columns() }}
from kept
