-- Current state of an order line, one row per order_number and line_number.
--
-- INCREMENTAL PATTERN: change feed (see _staging.yml)
--
-- The grain needs both columns. line_number restarts at 1 on every order, so
-- it is not a key on its own, which is why unique_key below is a list.

{{ config(
    materialized = 'incremental',
    unique_key = ['order_number', 'line_number'],
    incremental_strategy = 'delete+insert'
) }}

with source as (

    select * from {{ source('erp', 'order_line') }}

    {% if is_incremental() %}
    where change_ts >= (select max(_change_ts) from {{ this }})
    {% endif %}

),

latest_change as (

    select *
    from source
    qualify row_number() over (
        partition by order_number, line_number
        order by change_ts desc, filename desc
    ) = 1

),

current_state as (

    select
        order_number,
        line_number,
        product_id,
        quantity,
        unit_price,

        -- Reconciles to quantity * unit_price exactly on every line in the
        -- landing zone today. Pinned by
        -- tests/assert_erp_line_amount_reconciles.sql so we hear about the day
        -- that stops being true, rather than trusting a comment about it.
        line_amount,

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
    on  current_state.order_number = prior.order_number
    and current_state.line_number  = prior.line_number
{% endif %}
