-- Branch dimension, built from the ERP (Enterprise Resource Planning) branch change feed.
-- Grain: one row per branch_id per valid_from_ts. Each change the feed sent for a branch
-- becomes one version of that branch, valid from its change_ts until the next change_ts.
--
-- The first version of a branch starts at its first change_ts. It is not stretched back to
-- the beginning of time: CONVENTIONS.md says a change applies from the day it happened, and
-- what applied before the change feed began is not recorded anywhere.
-- A delete (op D) is kept as a version of its own, with is_deleted true.
-- The website is a branch, so the WEB row is kept like any other.

with branch_changes as (

    select * from {{ ref('stg_erp__branches') }}

),

versioned as (

    select
        branch_id,
        branch_name,
        city,
        state,
        timezone,
        opened_date,
        change_ts as valid_from_ts,
        -- The version ends when the next change for the same branch begins.
        -- The latest version has no next change, so its end is null (still open).
        lead(change_ts) over (
            partition by branch_id
            order by change_ts
        ) as valid_to_ts,
        is_deleted
    from branch_changes

)

select
    {{ generate_surrogate_key(['branch_id', 'valid_from_ts']) }} as branch_key,
    branch_id,
    branch_name,
    city,
    state,
    timezone,
    opened_date,
    valid_from_ts,
    valid_to_ts,
    valid_to_ts is null as is_current,
    is_deleted,
    {{ audit_columns() }}
from versioned
