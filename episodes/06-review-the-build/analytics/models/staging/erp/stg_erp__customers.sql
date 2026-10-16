-- Staging model for the ERP (Enterprise Resource Planning) customer change feed.
-- Grain: one row per customer_number per change_ts.
-- The feed is CDC (change data capture), so every row it sends is kept, deletes included.
-- This model renames and casts only. It does not collapse to the current state of a customer.

with source as (

    select * from {{ source('erp', 'customer') }}

),

renamed as (

    select
        customer_number,
        customer_name,
        industry_code,
        city,
        state,
        cast(credit_limit as decimal(18, 2))  as credit_limit_amount,
        -- created_on and updated_on are the source system's own record timestamps. They take a
        -- source_ prefix because updated_ts is the name of an audit column.
        cast(created_on as timestamptz)       as source_created_ts,
        cast(updated_on as timestamptz)       as source_updated_ts,
        op,
        op = 'D'                              as is_deleted,
        cast(change_ts as timestamptz)        as change_ts,
        cast(_ingested_at as timestamptz)     as ingested_ts,
        filename                              as source_file_name
    from source

)

select
    {{ generate_surrogate_key(['customer_number', 'change_ts']) }} as stg_customer_key,
    *,
    {{ audit_columns() }}
from renamed
