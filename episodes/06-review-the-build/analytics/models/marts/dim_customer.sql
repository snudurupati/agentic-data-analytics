-- Customer dimension, built from the ERP (Enterprise Resource Planning) customer change feed.
-- Grain: one row per customer_number per valid_from_ts. Each change the feed sent for a
-- customer becomes one version of that customer, valid from its change_ts until the next
-- change_ts.
--
-- ERP customers only. CRM (Customer Relationship Management) and e-commerce customers use
-- different keys, and REQUIREMENTS.md does not allow a report to match or join customers
-- across source systems until the sales manager approves a matching rule.
--
-- The first version of a customer starts at its first change_ts. It is not stretched back to
-- the beginning of time: CONVENTIONS.md says a change applies from the day it happened, and
-- what applied before the change feed began is not recorded anywhere.
-- A delete (op D) is kept as a version of its own, with is_deleted true. Nothing is removed:
-- CONVENTIONS.md says deleting a customer does not erase its history.

with customer_changes as (

    select * from {{ ref('stg_erp__customers') }}

),

versioned as (

    select
        customer_number,
        customer_name,
        industry_code,
        city,
        state,
        credit_limit_amount,
        source_created_ts,
        source_updated_ts,
        change_ts as valid_from_ts,
        -- The version ends when the next change for the same customer begins.
        -- The latest version has no next change, so its end is null (still open).
        lead(change_ts) over (
            partition by customer_number
            order by change_ts
        ) as valid_to_ts,
        is_deleted
    from customer_changes

)

select
    {{ generate_surrogate_key(['customer_number', 'valid_from_ts']) }} as customer_key,
    customer_number,
    customer_name,
    industry_code,
    city,
    state,
    credit_limit_amount,
    source_created_ts,
    source_updated_ts,
    valid_from_ts,
    valid_to_ts,
    valid_to_ts is null as is_current,
    is_deleted,
    {{ audit_columns() }}
from versioned
