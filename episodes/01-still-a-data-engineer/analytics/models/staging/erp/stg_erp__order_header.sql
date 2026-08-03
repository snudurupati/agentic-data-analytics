{{
    config(
        unique_key='order_number'
    )
}}

with source as (
    select * from {{ source('erp', 'order_header') }}

    {% if is_incremental() %}
    where filename not in (select distinct source_file from {{ this }})
    {% endif %}
),

renamed as (
    select
        order_number,
        customer_number,
        branch_id,
        order_datetime,
        order_total,
        currency,
        status,
        op,
        change_ts,
        filename as source_file
    from source
)

-- op is passed through, not filtered, so a deleted order (op = 'D') still
-- shows up here with its last known values. Marts decide what to do with it.
select *
from renamed
qualify row_number() over (
    partition by order_number
    order by change_ts desc, source_file desc
) = 1
