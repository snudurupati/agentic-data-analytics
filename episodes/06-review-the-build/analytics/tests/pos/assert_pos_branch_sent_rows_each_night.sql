/*
    assert_pos_branch_sent_rows_each_night

    Checks: for every nightly POS (point of sale) load, every physical branch that was open by
    that night sent at least one row. Returns one row per branch per night with no rows.

    Why: CONVENTIONS.md counts the point of sale feed per branch. A branch that sends nothing is
    late even when the other branches arrive. A late feed fails a test but does not fail the
    job, so this test warns.

    How:
      - A nightly load is one file; its date is the yyyymmdd in the file name. Every night from
        the first loaded file to the last is expected, so a night with no file at all shows
        every branch as late. A night after the last loaded file cannot be seen here.
      - The branch list is stg_erp__branches, the ERP (Enterprise Resource Planning) change
        feed. For each night the test takes each branch's latest row with a change_ts on or
        before that night, and keeps it when it is not deleted and its opened_date is on or
        before that night.
      - A physical branch is a branch with a city. CONVENTIONS.md says the website has no city
        because there is no building, and the website never sends POS rows.
*/

{{ config(severity = 'warn') }}

with loads as (

    select distinct
        strptime(regexp_extract(source_file_name, 'transaction_(\d{8})', 1), '%Y%m%d')::date
            as load_date,
        branch_id
    from {{ ref('stg_pos__transactions') }}

),

nights as (

    select cast(night as date) as load_date
    from (
        select unnest(generate_series(min(load_date), max(load_date), interval 1 day)) as night
        from loads
    )

),

branch_as_of_night as (

    select
        nights.load_date,
        branches.branch_id,
        branches.city,
        branches.opened_date,
        branches.is_deleted,
        row_number() over (
            partition by nights.load_date, branches.branch_id
            order by branches.change_ts desc
        ) as version_rank
    from nights
    inner join {{ ref('stg_erp__branches') }} as branches
        on cast(branches.change_ts as date) <= nights.load_date

),

expected as (

    select load_date, branch_id
    from branch_as_of_night
    where version_rank = 1
      and not is_deleted
      and city is not null
      and opened_date <= load_date

)

select
    expected.load_date,
    expected.branch_id
from expected
left join loads
    on loads.load_date = expected.load_date
   and loads.branch_id = expected.branch_id
where loads.branch_id is null
order by expected.load_date, expected.branch_id
