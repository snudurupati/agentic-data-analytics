{{
    config(
        unique_key='account_id'
    )
}}

with source as (
    select * from {{ source('crm', 'account') }}

    {% if is_incremental() %}
    where "LastModifiedDate" > (select max(last_modified_at) from {{ this }})
    {% endif %}
),

renamed as (
    select
        "Id" as account_id,
        "Name" as account_name,
        "Industry" as industry,
        "BillingCity" as billing_city,
        "BillingState" as billing_state,
        "AccountSource" as account_source,
        "Owner" as owner_name,
        "LastModifiedDate" as last_modified_at,
        filename as source_file
    from source
)

select *
from renamed
qualify row_number() over (
    partition by account_id
    order by last_modified_at desc, source_file desc
) = 1
