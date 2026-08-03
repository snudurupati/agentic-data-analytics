{{
    config(
        unique_key=['order_number', 'line_number']
    )
}}

with source as (
    select * from {{ source('erp', 'order_line') }}

    {% if is_incremental() %}
    where change_ts > (select max(change_ts) from {{ this }})
    {% endif %}
),

renamed as (
    select
        order_number,
        line_number,
        product_id,
        quantity,
        unit_price,
        line_amount,
        op,
        change_ts,
        filename as source_file
    from source
)

-- op is passed through, not filtered, so a deleted line (op = 'D') still
-- shows up here with its last known values. Marts decide what to do with it.
select *
from renamed
qualify row_number() over (
    partition by order_number, line_number
    order by change_ts desc, source_file desc
) = 1
