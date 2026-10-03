-- The latest version of each ERP (Enterprise Resource Planning) order line.
-- Grain: one row per order_number per line_number.
--
-- The ERP change feed sends a correction to a line as a new row (op U). Staging keeps every
-- row, so this model picks the one with the latest change_ts for each line.
-- A deleted line (latest row is op D) is kept, with is_deleted true.

with line_changes as (

    select * from {{ ref('stg_erp__order_lines') }}

),

latest_version as (

    select
        order_number,
        line_number,
        product_id,
        quantity,
        unit_price_amount,
        line_amount,
        is_deleted,
        change_ts as last_change_ts
    from line_changes
    qualify row_number() over (
        partition by order_number, line_number
        order by change_ts desc
    ) = 1

)

select
    {{ generate_surrogate_key(['order_number', 'line_number']) }} as order_line_key,
    *,
    {{ audit_columns() }}
from latest_version
