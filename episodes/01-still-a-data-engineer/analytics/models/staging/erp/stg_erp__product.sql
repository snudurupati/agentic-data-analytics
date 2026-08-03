{{
    config(
        unique_key='product_id'
    )
}}

with source as (
    select * from {{ source('erp', 'product') }}

    {% if is_incremental() %}
    where change_ts > (select max(change_ts) from {{ this }})
    {% endif %}
),

renamed as (
    select
        product_id,
        sku,
        product_name,
        category,
        uom,
        unit_cost,
        list_price,
        op,
        change_ts,
        filename as source_file
    from source
)

-- op is passed through, not filtered, so a discontinued product (op = 'D')
-- still shows up here with its last known values. Marts decide what to do with it.
select *
from renamed
qualify row_number() over (
    partition by product_id
    order by change_ts desc, source_file desc
) = 1
