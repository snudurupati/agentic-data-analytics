-- Current state of an e-commerce customer, one row per customer_id.
--
-- INCREMENTAL PATTERN: full snapshot (see _staging.yml)
--
-- Same shape as stg_crm__accounts: the platform re-sends every customer every
-- night, and updated_at is the watermark that separates the handful that
-- changed from the majority that did not.
--
-- The same blind spot applies. A customer removed from the storefront simply
-- stops appearing in the snapshot, with no tombstone, so it stays in this
-- model indefinitely.
--
-- These customers are NOT the same population as stg_erp__customers, and there
-- is no shared key between them. email_domain is the only plausible bridge and
-- it is not reliable. Joining the two is an unsolved problem, not a missing
-- join condition.

{{ config(
    materialized = 'incremental',
    unique_key = 'customer_id',
    incremental_strategy = 'delete+insert'
) }}

with source as (

    select * from {{ source('ecom', 'customer') }}

    {% if is_incremental() %}
    where updated_at >= (select max(updated_at) from {{ this }})
    {% endif %}

),

-- Ordered by the record's own timestamp first and the earliest file second,
-- not by filename alone. See the equivalent block in stg_crm__accounts.sql:
-- ordering by filename makes _source_file depend on whether the table was
-- built incrementally or from a full refresh, which makes the two build paths
-- disagree.
latest_snapshot as (

    select *
    from source
    qualify row_number() over (
        partition by customer_id
        order by updated_at desc, filename asc
    ) = 1

),

current_state as (

    select
        customer_id,
        company_name,
        email_domain,
        contact_email,
        country,
        created_at,
        updated_at,
        filename    as _source_file

    from latest_snapshot

)

select
    current_state.*,
    {{ audit_columns() }}

from current_state
{% if is_incremental() %}
left join {{ this }} as prior
    on current_state.customer_id = prior.customer_id
{% endif %}
