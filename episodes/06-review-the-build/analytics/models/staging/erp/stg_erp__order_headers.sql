-- Staging model for the ERP (Enterprise Resource Planning) order header change feed.
-- Grain: one row per order_number per change_ts.
-- The feed is CDC (change data capture), so every row it sends is kept, deletes included.

with source as (

    select * from {{ source('erp', 'order_header') }}

),

renamed as (

    select
        order_number,
        customer_number,
        branch_id,
        -- order_datetime carries an offset such as -05:00; timestamptz keeps the same instant.
        cast(order_datetime as timestamptz)  as order_ts,
        -- The calendar date as the ERP wrote it, in the source's own offset, with no time zone
        -- conversion: the first ten characters of the text, for example 2026-07-21.
        cast(left(order_datetime, 10) as date)  as source_order_date,
        cast(order_total as decimal(18, 2))  as order_total_amount,
        currency,
        status,
        op,
        op = 'D'                             as is_deleted,
        cast(change_ts as timestamptz)       as change_ts,
        cast(_ingested_at as timestamptz)    as ingested_ts,
        filename                             as source_file_name
    from source

)

select
    {{ generate_surrogate_key(['order_number', 'change_ts']) }} as stg_order_header_key,
    *,
    {{ audit_columns() }}
from renamed
