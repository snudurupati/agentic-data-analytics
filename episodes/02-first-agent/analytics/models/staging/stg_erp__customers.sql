-- Current state of the enterprise resource planning (ERP) customer, one row
-- per customer_number.
--
-- INCREMENTAL PATTERN: change feed (see _staging.yml for the full explanation)
--
-- The watermark is change_ts, the capture time of the change. It works because
-- the globally latest change is by definition the latest change for its own
-- key, so it always survives the collapse below, which means max(_change_ts)
-- in this table is exactly the high water mark of everything processed so far.
--
-- `>=` rather than `>` so a tie on the boundary timestamp is reprocessed
-- rather than skipped. Reprocessing is harmless because the collapse and the
-- delete+insert are both idempotent.

{{ config(
    materialized = 'incremental',
    unique_key = 'customer_number',
    incremental_strategy = 'delete+insert'
) }}

with source as (

    select * from {{ source('erp', 'customer') }}

    {% if is_incremental() %}
    where change_ts >= (select max(_change_ts) from {{ this }})
    {% endif %}

),

latest_change as (

    select *
    from source
    qualify row_number() over (
        partition by customer_number
        order by change_ts desc, filename desc
    ) = 1

),

current_state as (

    select
        customer_number,
        customer_name,
        industry_code,
        city,
        state,
        credit_limit,
        created_on          as created_at,
        updated_on          as updated_at,

        -- Marked deleted, never removed. Dropping it here would mean nobody
        -- downstream could answer when the customer closed, or that it ever
        -- existed. What to do about it is a marts decision, and it needs the
        -- row to still be here in order to be made.
        op = 'D'            as is_deleted,

        change_ts           as _change_ts,
        filename            as _source_file

    from latest_change

)

select
    current_state.*,
    {{ audit_columns() }}

from current_state
{% if is_incremental() %}
left join {{ this }} as prior
    on current_state.customer_number = prior.customer_number
{% endif %}
