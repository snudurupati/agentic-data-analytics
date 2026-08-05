-- Current state of a product, one row per product_id.
--
-- INCREMENTAL PATTERN: change feed (see _staging.yml)
--
-- unit_cost and list_price change over time, and this model keeps only the
-- current values. Anything that needs the price as it stood on the day of a
-- sale has to read the change feed itself rather than join to this.

{{ config(
    materialized = 'incremental',
    unique_key = 'product_id',
    incremental_strategy = 'delete+insert'
) }}

with source as (

    select * from {{ source('erp', 'product') }}

    {% if is_incremental() %}
    where change_ts >= (select max(_change_ts) from {{ this }})
    {% endif %}

),

latest_change as (

    select *
    from source
    qualify row_number() over (
        partition by product_id
        order by change_ts desc, filename desc
    ) = 1

),

current_state as (

    select
        product_id,
        sku,
        product_name,
        category,
        uom         as unit_of_measure,
        unit_cost,
        list_price,
        op = 'D'    as is_deleted,
        change_ts   as _change_ts,
        filename    as _source_file

    from latest_change

)

select
    current_state.*,
    {{ audit_columns() }}

from current_state
{% if is_incremental() %}
left join {{ this }} as prior
    on current_state.product_id = prior.product_id
{% endif %}
