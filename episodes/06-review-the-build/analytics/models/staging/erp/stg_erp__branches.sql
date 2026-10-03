-- Staging model for the ERP (Enterprise Resource Planning) branch change feed.
-- Grain: one row per branch_id per change_ts.
-- The feed is CDC (change data capture), so every row it sends is kept, deletes included.
-- This model renames and casts only. It does not collapse to the current state of a branch.

with source as (

    select * from {{ source('erp', 'branch') }}

),

renamed as (

    select
        branch_id,
        branch_name,
        city,
        state,
        timezone,
        cast(opened_date as date)          as opened_date,
        op,
        op = 'D'                           as is_deleted,
        -- change_ts carries an offset such as -05:00; timestamptz keeps the same instant.
        cast(change_ts as timestamptz)     as change_ts,
        cast(_ingested_at as timestamptz)  as ingested_ts,
        filename                           as source_file_name
    from source

)

select
    {{ generate_surrogate_key(['branch_id', 'change_ts']) }} as stg_branch_key,
    *,
    {{ audit_columns() }}
from renamed
