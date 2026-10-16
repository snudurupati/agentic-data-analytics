/*
    assert_pos_row_arrived_within_open_period

    Checks: every POS (point of sale) row arrived while the fourteen-day period for its sale
    date was still open. Returns the rows that arrived after the period closed.

    Why: CONVENTIONS.md says Finance allows fourteen days after the date of a sale for
    corrections. On day fifteen the period closes and the number is published. A row that turns
    up after that is an exception, not a correction. This is incoming data breaking a rule, so
    the test warns.

    How: the arrival date is the yyyymmdd in the file name, the night the warehouse loaded the
    row. received_at is not used, because the till writes it and nobody owns it. A sale on
    sale_date can arrive up to and including sale_date + 14 days; later is an exception.
*/

{{ config(severity = 'warn') }}

with arrivals as (

    select
        branch_id,
        transaction_id,
        sale_date,
        source_file_name,
        strptime(regexp_extract(source_file_name, 'transaction_(\d{8})', 1), '%Y%m%d')::date
            as load_date
    from {{ ref('stg_pos__transactions') }}

)

select
    branch_id,
    transaction_id,
    sale_date,
    load_date,
    source_file_name,
    load_date - sale_date as days_after_sale
from arrivals
where load_date > sale_date + 14
