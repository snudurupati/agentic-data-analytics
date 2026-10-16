-- Till sales from the POS (point of sale) feed, summed per branch per day.
-- Grain: one row per branch_id per sale_date, only where the branch sent at least one row
-- for that date.
--
-- sale_date is the branch's local calendar date of the sale, as the till wrote it.
-- A refund or return is its own transaction with a negative amount, so it reduces the total
-- of the day it happened on.
--
-- Staging can hold more than one version of the same (branch_id, transaction_id), for example
-- a correction or a void that reuses the ID. Which version counts has not been decided, so
-- every version is summed here and repeated_transaction_row_count says how many rows on that
-- branch-day belong to a transaction with more than one version.

with transactions as (

    select
        *,
        count(*) over (partition by branch_id, transaction_id) > 1 as has_several_versions
    from {{ ref('stg_pos__transactions') }}

),

summed as (

    select
        branch_id,
        sale_date,
        sum(sale_amount)                                    as sale_amount,
        sum(cost_amount)                                    as cost_amount,
        count(*)                                            as transaction_count,
        sum(item_count)                                     as item_count,
        count(*) filter (where has_several_versions)        as repeated_transaction_row_count
    from transactions
    group by branch_id, sale_date

)

select
    {{ generate_surrogate_key(['branch_id', 'sale_date']) }} as pos_branch_day_key,
    *,
    {{ audit_columns() }}
from summed
