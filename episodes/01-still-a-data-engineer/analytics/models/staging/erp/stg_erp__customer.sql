{{
    config(
        unique_key='customer_number'
    )
}}

with source as (
    select * from {{ source('erp', 'customer') }}

    {% if is_incremental() %}
    where change_ts > (select max(change_ts) from {{ this }})
    {% endif %}
),

renamed as (
    select
        customer_number,
        customer_name,
        industry_code,
        city,
        state,
        credit_limit,
        created_on,
        updated_on,
        op,
        change_ts,
        filename as source_file
    from source
)

-- op is passed through, not filtered, so a deleted customer (op = 'D') still
-- shows up here with its last known values. Marts decide what to do with it.
select *
from renamed
qualify row_number() over (
    partition by customer_number
    order by change_ts desc, source_file desc
) = 1
