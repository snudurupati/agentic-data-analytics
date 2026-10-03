/*
    No row in stg_ecom__customers repeats the row held before it for the same customer.

    STANDARDS.md: a full dump keeps only the rows that changed. A row that matches the previous
    row on every column the source sends, and on is_deleted, should not have been held.

    Returns one row per repeated row. Severity error: a repeat is a fault in the model.
*/
{{ config(severity = 'error') }}

with compared as (

    select
        customer_id,
        ingested_ts,
        company_name is not distinct from lag(company_name) over customer_history
            and email_domain is not distinct from lag(email_domain) over customer_history
            and contact_email is not distinct from lag(contact_email) over customer_history
            and country is not distinct from lag(country) over customer_history
            and source_created_ts is not distinct from lag(source_created_ts) over customer_history
            and source_updated_ts is not distinct from lag(source_updated_ts) over customer_history
            and is_deleted is not distinct from lag(is_deleted) over customer_history
            as is_same_as_previous,
        row_number() over customer_history as row_number_for_customer
    from {{ ref('stg_ecom__customers') }}
    window customer_history as (partition by customer_id order by ingested_ts)

)

select customer_id, ingested_ts
from compared
where row_number_for_customer > 1
  and is_same_as_previous
