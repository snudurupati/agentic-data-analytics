-- The latest version of each ERP (Enterprise Resource Planning) order header.
-- Grain: one row per order_number.
--
-- The ERP change feed sends a correction to an order as a new row (op U). Staging keeps every
-- row, so this model picks the one with the latest change_ts for each order.
-- A deleted order (latest row is op D) is kept, with is_deleted true. It is not dropped here,
-- because how a deleted order affects revenue has not been decided.

with header_changes as (

    select * from {{ ref('stg_erp__order_headers') }}

),

latest_version as (

    select
        order_number,
        customer_number,
        branch_id,
        order_ts,
        source_order_date,
        order_total_amount,
        currency,
        status,
        is_deleted,
        change_ts as last_change_ts
    from header_changes
    qualify row_number() over (
        partition by order_number
        order by change_ts desc
    ) = 1

)

select
    {{ generate_surrogate_key(['order_number']) }} as order_key,
    *,
    {{ audit_columns() }}
from latest_version
