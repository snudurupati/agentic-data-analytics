-- Current state of a customer relationship management (CRM) account, one row
-- per account_id.
--
-- INCREMENTAL PATTERN: full snapshot (see _staging.yml)
--
-- The CRM re-sends every account every night, so most of what lands is
-- unchanged and does not need reprocessing. LastModifiedDate is the watermark:
-- an account that has not been touched keeps its old timestamp and falls below
-- the mark, while a new or edited one carries a fresh timestamp and is picked
-- up. That turns a full snapshot into a genuinely incremental load.
--
-- WHAT THIS CANNOT SEE
--
-- A snapshot expresses a deletion by simply not containing the row. There is
-- no tombstone to detect, so an account deleted in the CRM stays in this model
-- forever. Nothing in this feed can fix that. Catching it means diffing two
-- consecutive snapshots, which is a different model with a different cost, and
-- it is not built here.

{{ config(
    materialized = 'incremental',
    unique_key = 'account_id',
    incremental_strategy = 'delete+insert'
) }}

with source as (

    select * from {{ source('crm', 'account') }}

    {% if is_incremental() %}
    where LastModifiedDate >= (select max(last_modified_at) from {{ this }})
    {% endif %}

),

-- One account can pass the watermark in more than one snapshot, so keep one.
--
-- The ordering here matters more than it looks, and ordering by filename alone
-- is wrong. It picks the newest snapshot the row appears in, so a full refresh
-- records the latest snapshot for every account, while an incremental run
-- leaves an untouched account pointing at whatever snapshot last wrote it.
-- Same data, different _source_file, which means `dbt build --full-refresh`
-- produced a different table from an incremental run. That quietly breaks the
-- one command you reach for when a load looks wrong.
--
-- Ordering by the record's own timestamp first and the earliest file second
-- defines _source_file as "the snapshot in which this version of the row first
-- appeared". That is the same answer whichever way the table was built.
latest_snapshot as (

    select *
    from source
    qualify row_number() over (
        partition by Id
        order by LastModifiedDate desc, filename asc
    ) = 1

),

current_state as (

    select
        Id                  as account_id,
        Name                as account_name,
        Industry            as industry,
        BillingCity         as billing_city,
        BillingState        as billing_state,
        AccountSource       as account_source,

        -- A person's name, not an identifier. There is no join from here to
        -- anything else in the project.
        Owner               as owner_name,

        LastModifiedDate    as last_modified_at,
        filename            as _source_file

    from latest_snapshot

)

select
    current_state.*,
    {{ audit_columns() }}

from current_state
{% if is_incremental() %}
left join {{ this }} as prior
    on current_state.account_id = prior.account_id
{% endif %}
