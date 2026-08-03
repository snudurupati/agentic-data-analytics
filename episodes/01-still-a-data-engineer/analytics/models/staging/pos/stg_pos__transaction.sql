{{
    config(
        unique_key='transaction_id'
    )
}}

with source as (
    select * from {{ source('pos', 'transaction') }}

    {% if is_incremental() %}
    where filename not in (select distinct source_file from {{ this }})
    {% endif %}
),

renamed as (
    select
        transaction_id,
        branch_id,
        sale_datetime,
        received_at,
        sale_amount,
        cost_amount,
        item_count,
        filename as source_file
    from source
)

select *
from renamed
qualify row_number() over (
    partition by transaction_id
    order by received_at desc, source_file desc
) = 1
