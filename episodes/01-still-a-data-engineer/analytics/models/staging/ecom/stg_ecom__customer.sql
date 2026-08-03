{{
    config(
        unique_key='customer_id'
    )
}}

with source as (
    select * from {{ source('ecom', 'customer') }}

    {% if is_incremental() %}
    where filename not in (select distinct source_file from {{ this }})
    {% endif %}
),

renamed as (
    select
        customer_id,
        company_name,
        email_domain,
        contact_email,
        country,
        created_at,
        updated_at,
        filename as source_file
    from source
)

select *
from renamed
qualify row_number() over (
    partition by customer_id
    order by updated_at desc, source_file desc
) = 1
