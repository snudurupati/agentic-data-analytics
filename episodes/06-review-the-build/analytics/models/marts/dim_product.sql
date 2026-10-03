-- Product dimension, built from the ERP (Enterprise Resource Planning) product change feed.
-- Grain: one row per product_id per valid_from_ts. Each change the feed sent for a product
-- becomes one version of that product, valid from its change_ts until the next change_ts.
--
-- unit_cost_amount is the cost that applied during the version's date range. A report looks up
-- the version valid at the time of the sale to find the cost that applied on that date.
--
-- The first version of a product starts at its first change_ts. It is not stretched back to
-- the beginning of time: CONVENTIONS.md says a change applies from the day it happened, and
-- what applied before the change feed began is not recorded anywhere.
-- A delete (op D) is kept as a version of its own, with is_deleted true.

with product_changes as (

    select * from {{ ref('stg_erp__products') }}

),

versioned as (

    select
        product_id,
        sku,
        product_name,
        category,
        unit_of_measure,
        unit_cost_amount,
        list_price_amount,
        change_ts as valid_from_ts,
        -- The version ends when the next change for the same product begins.
        -- The latest version has no next change, so its end is null (still open).
        lead(change_ts) over (
            partition by product_id
            order by change_ts
        ) as valid_to_ts,
        is_deleted
    from product_changes

)

select
    {{ generate_surrogate_key(['product_id', 'valid_from_ts']) }} as product_key,
    product_id,
    sku,
    product_name,
    category,
    unit_of_measure,
    unit_cost_amount,
    list_price_amount,
    valid_from_ts,
    valid_to_ts,
    valid_to_ts is null as is_current,
    is_deleted,
    {{ audit_columns() }}
from versioned
