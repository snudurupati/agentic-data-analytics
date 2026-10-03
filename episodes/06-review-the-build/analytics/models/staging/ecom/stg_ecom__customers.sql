/*
    stg_ecom__customers

    Reads the e-commerce customer source, which is a full table dump each night.
    A snapshot is one value of _ingested_at. Every snapshot resends every customer, so this
    model keeps only the rows that tell us something new:

      - the first time a customer appears;
      - when any column the source sends differs from the row held before it;
      - when a customer is present in one snapshot and absent from the next (a row in that next
        snapshot with is_deleted = true, carrying the last held values);
      - when a customer comes back after being marked deleted.

    The comparison ignores _ingested_at and filename, because they change on every sync.

    Grain: one row per customer_id per snapshot in which it changed.
*/

-- Step 1: read the source, rename the columns and cast them to real types.
with source_rows as (

    select
        customer_id,
        company_name,
        email_domain,
        contact_email,
        country,
        cast(created_at as timestamptz) as source_created_ts,
        cast(updated_at as timestamptz) as source_updated_ts,
        cast(_ingested_at as timestamptz) as ingested_ts,
        filename as source_file_name
    from {{ source('ecom', 'customer') }}

),

-- Step 2: list the snapshots in delivery order, and give each one the snapshot that follows it,
-- with that next snapshot's file. The last snapshot has no next snapshot, so the next_ columns
-- are null there. If one snapshot ever spans several files, the first file name in sort order
-- is used.
snapshots as (

    select
        ingested_ts,
        lead(ingested_ts) over (order by ingested_ts) as next_ingested_ts,
        lead(snapshot_file_name) over (order by ingested_ts) as next_source_file_name
    from (
        select
            ingested_ts,
            min(source_file_name) as snapshot_file_name
        from source_rows
        group by ingested_ts
    ) as distinct_snapshots

),

-- Step 3: every customer row as delivered, marked as not deleted.
present_rows as (

    select
        customer_id,
        company_name,
        email_domain,
        contact_email,
        country,
        source_created_ts,
        source_updated_ts,
        ingested_ts,
        source_file_name,
        false as is_deleted
    from source_rows

),

-- Step 4: customers present in one snapshot and absent from the next one.
-- Each becomes a row in that next snapshot, marked deleted, carrying the values it had when it
-- was last seen. Its ingested_ts and source_file_name are those of the snapshot it is missing from.
deleted_rows as (

    select
        present_rows.customer_id,
        present_rows.company_name,
        present_rows.email_domain,
        present_rows.contact_email,
        present_rows.country,
        present_rows.source_created_ts,
        present_rows.source_updated_ts,
        snapshots.next_ingested_ts as ingested_ts,
        snapshots.next_source_file_name as source_file_name,
        true as is_deleted
    from present_rows
    inner join snapshots
        on present_rows.ingested_ts = snapshots.ingested_ts
    where snapshots.next_ingested_ts is not null
      and not exists (
          select 1
          from present_rows as next_snapshot_rows
          where next_snapshot_rows.customer_id = present_rows.customer_id
            and next_snapshot_rows.ingested_ts = snapshots.next_ingested_ts
      )

),

-- Step 5: put the delivered rows and the deletion rows together, one row per customer per
-- snapshot.
all_rows as (

    select * from present_rows
    union all
    select * from deleted_rows

),

-- Step 6: for each row, look up the row for the same customer in the snapshot before it.
-- The previous_ columns are null on a customer's first row.
compared_to_previous as (

    select
        *,
        row_number() over customer_history as row_number_for_customer,
        lag(company_name) over customer_history as previous_company_name,
        lag(email_domain) over customer_history as previous_email_domain,
        lag(contact_email) over customer_history as previous_contact_email,
        lag(country) over customer_history as previous_country,
        lag(source_created_ts) over customer_history as previous_source_created_ts,
        lag(source_updated_ts) over customer_history as previous_source_updated_ts,
        lag(is_deleted) over customer_history as previous_is_deleted
    from all_rows
    window customer_history as (partition by customer_id order by ingested_ts)

),

-- Step 7: keep a row when it is the customer's first, when it was deleted or came back, or when
-- any column the source sends has changed. "is distinct from" treats two nulls as equal and a
-- null against a value as a change.
changed_rows as (

    select *
    from compared_to_previous
    where row_number_for_customer = 1
       or is_deleted is distinct from previous_is_deleted
       or company_name is distinct from previous_company_name
       or email_domain is distinct from previous_email_domain
       or contact_email is distinct from previous_contact_email
       or country is distinct from previous_country
       or source_created_ts is distinct from previous_source_created_ts
       or source_updated_ts is distinct from previous_source_updated_ts

)

-- Step 8: add the staging surrogate key and the audit columns.
select
    {{ generate_surrogate_key(['customer_id', 'ingested_ts']) }} as stg_customer_key,
    customer_id,
    company_name,
    email_domain,
    contact_email,
    country,
    source_created_ts,
    source_updated_ts,
    is_deleted,
    ingested_ts,
    source_file_name,
    {{ audit_columns() }}
from changed_rows
