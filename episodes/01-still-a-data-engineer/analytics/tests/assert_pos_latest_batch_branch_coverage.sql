-- Fail if a branch that normally reports point of sale (POS) sales is missing
-- from the most recent batch.
--
-- WHY SOURCE FRESHNESS CANNOT DO THIS
--
-- Freshness on the pos source asks "did anything arrive recently". Eight tills
-- feed it, and seven healthy ones keep max(received_at) current no matter what
-- the eighth does. So a single branch can go dark for days without moving the
-- number freshness looks at. It has already happened: BR07 uploaded nothing on
-- 2026-07-21, and 45 of its sales dated 07-20 arrived in the 07-22 file two
-- days late. No freshness threshold would have caught that.
--
-- WHY THE EXPECTED ROSTER IS NOT erp.branch
--
-- The obvious version of this test is "every branch in erp.branch must appear
-- tonight". That fails forever, because erp.branch carries nine rows and one
-- of them is WEB, the online store, which is a pseudo-branch with no till and
-- zero POS rows ever. A test that can never pass gets disabled, and then it is
-- protecting nothing.
--
-- So a branch is expected to report tonight only if it has reported in some
-- earlier batch. WEB never has, so it is never expected. A genuinely new
-- branch stays silent until its first upload, which is the right default,
-- because we cannot tell "not opened yet" apart from "till never installed".
--
-- WHY THE BATCH KEY IS THE FILENAME DATE
--
-- Tills push per branch, so one night can produce several files:
-- transaction_20260722_b.csv holds 28 rows from BR03 alone. Keying on the file
-- would compare a single-branch supplement against the full roster and fail
-- every time one arrives. The date inside the filename groups a main file with
-- its supplements. That trusts the naming convention, which is itself unowned,
-- but received_at cannot do the job: it is one constant per file and both
-- 07-22 files carry the same value, so it cannot separate them either.

-- The pattern is anchored to the `transaction_` prefix on purpose. Matching a
-- bare run of eight digits searches the whole path, not the file name, so a
-- landing zone mounted somewhere like /mnt/20260701/ or under a directory with
-- a long identifier in it would match the wrong digits, drop every file into
-- one batch, and quietly stop testing anything.
with reported as (

    select distinct
        regexp_extract(filename, 'transaction_([0-9]{8})', 1) as batch_date,
        branch_id
    from {{ source('pos', 'transaction') }}

),

latest_batch as (

    select max(batch_date) as batch_date
    from reported

),

-- Branches with a track record of reporting before tonight.
expected as (

    select distinct reported.branch_id
    from reported
    cross join latest_batch
    where reported.batch_date < latest_batch.batch_date

)

select
    latest_batch.batch_date as batch_date,
    expected.branch_id      as branch_id,
    'reported in an earlier batch but is absent from the latest one' as problem

from expected
cross join latest_batch

where not exists (
    select 1
    from reported
    where reported.batch_date = latest_batch.batch_date
      and reported.branch_id  = expected.branch_id
)
