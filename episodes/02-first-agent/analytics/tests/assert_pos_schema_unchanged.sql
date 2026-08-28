-- Fail if the point of sale (POS) file shape changes in any way.
--
-- Nobody owns the format of these files. Branch tills write them and push them
-- into shared storage, so a column can be added, removed, renamed or retyped
-- without anyone being told. This test is the notification.
--
-- It catches three separate things, which is why it compares the whole shape
-- rather than just checking a few columns exist:
--
--   column added     A new column appears. Harmless on its own, but it means
--                    the till software changed, so read the file before
--                    trusting anything else in the batch.
--   type changed     DuckDB infers types by sampling the files. A till writing
--                    "12.50 USD" instead of 12.50 turns sale_amount from
--                    DOUBLE into VARCHAR, and every downstream sum with it.
--
-- WHAT THIS TEST DOES NOT CATCH
--
-- A column dropped by one till, or in one night's file, is invisible here.
-- `union_by_name = true` unions every file in the glob, so as long as one
-- older file still carries cost_amount the union still has a cost_amount
-- column and the shape below still matches. This test only notices once every
-- file in the landing zone has stopped sending it, which is far too late.
--
-- That gap is covered instead by the not_null tests on the POS source columns
-- in _sources_pos.yml. union_by_name fills the missing column with nulls, so a
-- column dropped from a single file shows up immediately as a not_null
-- failure. The two tests are complements, and neither one alone is enough.
--
-- The expected list below includes `filename`, which the source adds itself
-- via filename = true and which is not a column in the files.
--
-- When this test fails, the fix is to look at the new file and decide what
-- changed, then update this list deliberately. Updating the list to make the
-- test pass without doing that defeats the entire point of having it.

with actual as (

    select column_name, column_type
    from (describe select * from {{ source('pos', 'transaction') }})

),

expected as (

    select *
    from (
        values
            ('transaction_id', 'VARCHAR'),
            ('branch_id',      'VARCHAR'),
            ('sale_datetime',  'TIMESTAMP'),
            ('received_at',    'TIMESTAMP WITH TIME ZONE'),
            ('sale_amount',    'DOUBLE'),
            ('cost_amount',    'DOUBLE'),
            ('item_count',     'BIGINT'),
            ('filename',       'VARCHAR')
    ) as t (column_name, column_type)

)

select
    coalesce(actual.column_name, expected.column_name) as column_name,
    expected.column_type                              as expected_type,
    actual.column_type                                as actual_type,
    case
        when expected.column_name is null then 'column added'
        when actual.column_name is null   then 'column removed'
        else 'type changed'
    end                                               as problem

from actual
full outer join expected
    on actual.column_name = expected.column_name

where actual.column_name is null
   or expected.column_name is null
   or actual.column_type != expected.column_type
