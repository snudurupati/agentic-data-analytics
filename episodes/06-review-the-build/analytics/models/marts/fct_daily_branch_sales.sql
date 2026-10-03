-- Daily branch sales report (REQUIREMENTS.md).
-- Grain: one row per branch_id per sale_date. A row exists only where the branch had at least
-- one till sale or one order that day; a day with no activity has no row.
--
-- It combines two kinds of sale, which REQUIREMENTS.md says never overlap:
--   - POS (point of sale) till sales. sale_date is the branch's local date of the sale.
--   - ERP (Enterprise Resource Planning) orders, including web orders (branch WEB). sale_date
--     is the order_date from fct_order, which is provisional.
--
-- The totals (revenue, cost, margin, transaction count, item count) are the POS part plus the
-- order part. The parts are published too, so a reader can see what each total is made of.
--
-- A total is null where it depends on a decision nobody has made, and a count column says how
-- many inputs are affected:
--   - cost_amount and margin_amount are null when any order line that day has an unknown cost
--     (uncosted_order_line_count > 0). A partial cost is not published as if it were complete.
--   - every total is null when the day holds a deleted order or line (how a deletion affects
--     revenue is undecided), or a till transaction with more than one version (which version
--     counts is undecided).
--
-- period_close_date is sale_date plus 14 days: CONVENTIONS.md allows fourteen days for
-- corrections, and the period closes on day fifteen. is_period_closed compares it with the date
-- the model was built (current_date at build time), so it is only as fresh as the last build.
-- No rates are published. Margin percent is left to the reader (REQUIREMENTS.md).

with pos_sales as (

    select * from {{ ref('int_pos_sales_by_branch_day') }}

),

order_sales as (

    select * from {{ ref('int_order_sales_by_branch_day') }}

),

combined as (

    select
        coalesce(pos_sales.branch_id, order_sales.branch_id)            as branch_id,
        coalesce(pos_sales.sale_date, order_sales.source_order_date)    as sale_date,

        coalesce(pos_sales.sale_amount, 0)                     as pos_revenue_amount,
        coalesce(order_sales.order_total_amount, 0)            as order_revenue_amount,
        coalesce(pos_sales.transaction_count, 0)               as pos_transaction_count,
        coalesce(order_sales.order_count, 0)                   as order_count,
        coalesce(pos_sales.item_count, 0)                      as pos_item_count,
        coalesce(order_sales.item_count, 0)                    as order_item_count,
        coalesce(pos_sales.cost_amount, 0)                     as pos_cost_amount,
        coalesce(order_sales.known_cost_amount, 0)             as known_order_cost_amount,
        coalesce(order_sales.line_count, 0)                    as order_line_count,
        coalesce(order_sales.uncosted_line_count, 0)           as uncosted_order_line_count,
        coalesce(order_sales.deleted_order_count, 0)           as deleted_order_count,
        coalesce(order_sales.deleted_line_count, 0)            as deleted_order_line_count,
        coalesce(pos_sales.repeated_transaction_row_count, 0)  as pos_repeated_transaction_row_count
    from pos_sales
    full outer join order_sales
        on pos_sales.branch_id = order_sales.branch_id
        and pos_sales.sale_date = order_sales.source_order_date

),

flagged as (

    select
        *,
        -- True when a total depends on a decision nobody has made (see the header).
        (
            deleted_order_count > 0
            or deleted_order_line_count > 0
            or pos_repeated_transaction_row_count > 0
        ) as has_undecided_rows,
        uncosted_order_line_count > 0 as has_unknown_cost
    from combined

),

totals as (

    select
        *,
        case when not has_undecided_rows
            then pos_revenue_amount + order_revenue_amount
        end as revenue_amount,
        case when not has_undecided_rows and not has_unknown_cost
            then pos_cost_amount + known_order_cost_amount
        end as cost_amount,
        case when not has_undecided_rows
            then pos_transaction_count + order_count
        end as transaction_count,
        case when not has_undecided_rows
            then pos_item_count + order_item_count
        end as item_count
    from flagged

)

select
    {{ generate_surrogate_key(['branch_id', 'sale_date']) }} as daily_branch_sales_key,
    branch_id,
    sale_date,
    revenue_amount,
    cost_amount,
    revenue_amount - cost_amount                 as margin_amount,
    transaction_count,
    item_count,
    pos_revenue_amount,
    order_revenue_amount,
    pos_cost_amount,
    known_order_cost_amount,
    pos_transaction_count,
    order_count,
    pos_item_count,
    order_item_count,
    order_line_count,
    uncosted_order_line_count,
    deleted_order_count,
    deleted_order_line_count,
    pos_repeated_transaction_row_count,
    sale_date + 14                               as period_close_date,
    current_date > sale_date + 14                as is_period_closed,
    {{ audit_columns() }}
from totals
