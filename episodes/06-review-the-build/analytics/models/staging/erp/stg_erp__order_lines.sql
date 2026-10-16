-- Staging model for the ERP (Enterprise Resource Planning) order line change feed.
-- Grain: one row per order_number, line_number and change_ts.
-- The feed is CDC (change data capture), so every row it sends is kept, deletes included.

with source as (

    select * from {{ source('erp', 'order_line') }}

),

renamed as (

    select
        order_number,
        cast(line_number as integer)         as line_number,
        product_id,
        cast(quantity as integer)            as quantity,
        cast(unit_price as decimal(18, 2))   as unit_price_amount,
        cast(line_amount as decimal(18, 2))  as line_amount,
        op,
        op = 'D'                             as is_deleted,
        cast(change_ts as timestamptz)       as change_ts,
        cast(_ingested_at as timestamptz)    as ingested_ts,
        filename                             as source_file_name
    from source

)

select
    {{ generate_surrogate_key(['order_number', 'line_number', 'change_ts']) }} as stg_order_line_key,
    *,
    {{ audit_columns() }}
from renamed
