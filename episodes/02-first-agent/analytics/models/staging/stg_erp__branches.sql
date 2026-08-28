-- Current state of a branch, one row per branch_id.
--
-- INCREMENTAL PATTERN: change feed (see _staging.yml)
--
-- Note that this table carries a WEB pseudo-branch for the online store. It
-- has no till and never appears in point of sale data, which is why the branch
-- coverage test derives its expected roster from what has reported before
-- rather than from this model.

{{ config(
    materialized = 'incremental',
    unique_key = 'branch_id',
    incremental_strategy = 'delete+insert'
) }}

with source as (

    select * from {{ source('erp', 'branch') }}

    {% if is_incremental() %}
    where change_ts >= (select max(_change_ts) from {{ this }})
    {% endif %}

),

latest_change as (

    select *
    from source
    qualify row_number() over (
        partition by branch_id
        order by change_ts desc, filename desc
    ) = 1

),

current_state as (

    select
        branch_id,
        branch_name,
        city,
        state,

        -- The only place a branch's local time is recorded. Point of sale
        -- transactions carry no offset, so anything comparing a sale to
        -- another timestamp has to come through here first.
        timezone,

        opened_date,
        op = 'D'    as is_deleted,
        change_ts   as _change_ts,
        filename    as _source_file

    from latest_change

)

select
    current_state.*,
    {{ audit_columns() }}

from current_state
{% if is_incremental() %}
left join {{ this }} as prior
    on current_state.branch_id = prior.branch_id
{% endif %}
