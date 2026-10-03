-- Structural check on stg_crm__accounts.
-- A row the source sent is kept only when it differs from the row held before it, unless it
-- is the first row for the account or follows a deletion row. Returns every kept row that
-- repeats the row before it with no change.

with ordered as (

    select
        *,
        lag(is_deleted) over (partition by id order by ingested_ts) as previous_is_deleted,
        lag(name) over (partition by id order by ingested_ts) as previous_name,
        lag(industry) over (partition by id order by ingested_ts) as previous_industry,
        lag(billing_city) over (partition by id order by ingested_ts) as previous_billing_city,
        lag(billing_state) over (partition by id order by ingested_ts) as previous_billing_state,
        lag(account_source) over (partition by id order by ingested_ts) as previous_account_source,
        lag(owner) over (partition by id order by ingested_ts) as previous_owner,
        lag(last_modified_ts) over (partition by id order by ingested_ts) as previous_last_modified_ts,
        row_number() over (partition by id order by ingested_ts) as position
    from {{ ref('stg_crm__accounts') }}

)

select id, ingested_ts
from ordered
where position > 1
  and not is_deleted
  and not previous_is_deleted
  and name is not distinct from previous_name
  and industry is not distinct from previous_industry
  and billing_city is not distinct from previous_billing_city
  and billing_state is not distinct from previous_billing_state
  and account_source is not distinct from previous_account_source
  and owner is not distinct from previous_owner
  and last_modified_ts is not distinct from previous_last_modified_ts
