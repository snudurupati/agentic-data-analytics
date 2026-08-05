-- Current state of an order, one row per order_number.
--
-- INCREMENTAL PATTERN: change feed (see _staging.yml)
--
-- Orders move through statuses, so the same order_number appears in the feed
-- once per status change. The collapse below keeps the most recent one, which
-- means this model answers "what is the status now" and cannot answer "what
-- was the status on Tuesday".

{{ config(
    materialized = 'incremental',
    unique_key = 'order_number',
    incremental_strategy = 'delete+insert'
) }}

with source as (

    select * from {{ source('erp', 'order_header') }}

    {% if is_incremental() %}
    where change_ts >= (select max(_change_ts) from {{ this }})
    {% endif %}

),

latest_change as (

    select *
    from source
    qualify row_number() over (
        partition by order_number
        order by change_ts desc, filename desc
    ) = 1

),

current_state as (

    select
        order_number,
        customer_number,
        branch_id,
        order_datetime  as ordered_at,
        order_total,
        currency,
        status,
        op = 'D'        as is_deleted,
        change_ts       as _change_ts,
        filename        as _source_file

    from latest_change

)

select
    current_state.*,
    {{ audit_columns() }}

from current_state
{% if is_incremental() %}
left join {{ this }} as prior
    on current_state.order_number = prior.order_number
{% endif %}
