{{
    config(
        unique_key='branch_id'
    )
}}

with source as (
    select * from {{ source('erp', 'branch') }}

    {% if is_incremental() %}
    where filename not in (select distinct source_file from {{ this }})
    {% endif %}
),

renamed as (
    select
        branch_id,
        branch_name,
        city,
        state,
        timezone,
        opened_date,
        op,
        change_ts,
        filename as source_file
    from source
)

-- op is passed through, not filtered, so a deleted branch (op = 'D') still
-- shows up here with its last known values. Marts decide what to do with it.
select *
from renamed
qualify row_number() over (
    partition by branch_id
    order by change_ts desc, source_file desc
) = 1
