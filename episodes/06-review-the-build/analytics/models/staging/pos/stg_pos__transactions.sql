/*
    stg_pos__transactions

    Grain: one row per distinct version of a till transaction. A version is one combination of
    the seven columns the till sends (branch_id, transaction_id, sale_datetime, received_at,
    sale_amount, cost_amount, item_count). The same (branch_id, transaction_id) can appear
    more than once when a till resends it with different values, for example a correction or
    a zero-amount void that reuses the original transaction ID. Every such version is kept.

    Reads one source table: pos.transaction, every file in landing/pos/.

    What this model does:
      1. Casts every column from text to its real type.
      2. Drops a row only when an identical row (all seven till-sent columns equal after
         casting) is already held for the same (branch_id, transaction_id). The row kept is
         the one from the earliest file. The file name is not part of the comparison, because
         it changes on every delivery whether the row changed or not.
      3. Adds the staging surrogate key and the audit columns.

    Transaction IDs are not unique across branches, so branch_id is always part of the key.

    sale_datetime is branch local time with no time zone. It stays that way here, because
    converting it needs the branch table and a staging model reads one source.
*/

with source as (

    select * from {{ source('pos', 'transaction') }}

),

typed as (

    select
        branch_id,
        transaction_id,
        cast(sale_datetime as timestamp) as sale_local_ts,
        cast(received_at as timestamp with time zone) as received_ts,
        cast(sale_amount as decimal(18, 2)) as sale_amount,
        cast(cost_amount as decimal(18, 2)) as cost_amount,
        cast(item_count as integer) as item_count,
        filename as source_file_name
    from source

),

numbered as (

    -- Number the identical copies of each row, earliest file first. Copy 1 is kept.
    select
        *,
        row_number() over (
            partition by
                branch_id,
                transaction_id,
                sale_local_ts,
                received_ts,
                sale_amount,
                cost_amount,
                item_count
            order by source_file_name
        ) as copy_number
    from typed

)

select
    {{ generate_surrogate_key([
        'branch_id',
        'transaction_id',
        'sale_local_ts',
        'received_ts',
        'sale_amount',
        'cost_amount',
        'item_count'
    ]) }} as stg_transaction_key,
    branch_id,
    transaction_id,
    sale_local_ts,
    cast(sale_local_ts as date) as sale_date,
    received_ts,
    sale_amount,
    cost_amount,
    item_count,
    source_file_name,
    {{ audit_columns() }}
from numbered
where copy_number = 1
