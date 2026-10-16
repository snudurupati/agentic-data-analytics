-- Staging model for the ERP (Enterprise Resource Planning) product change feed.
-- Grain: one row per product_id per change_ts.
-- The feed is CDC (change data capture), so every row it sends is kept, deletes included.
-- A cost change arrives as a U (update) row, so each product's cost history is kept here.

with source as (

    select * from {{ source('erp', 'product') }}

),

renamed as (

    select
        product_id,
        sku,
        product_name,
        category,
        uom                                 as unit_of_measure,
        cast(unit_cost as decimal(18, 2))   as unit_cost_amount,
        cast(list_price as decimal(18, 2))  as list_price_amount,
        op,
        op = 'D'                            as is_deleted,
        cast(change_ts as timestamptz)      as change_ts,
        cast(_ingested_at as timestamptz)   as ingested_ts,
        filename                            as source_file_name
    from source

)

select
    {{ generate_surrogate_key(['product_id', 'change_ts']) }} as stg_product_key,
    *,
    {{ audit_columns() }}
from renamed
