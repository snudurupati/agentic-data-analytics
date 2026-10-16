/*
    assert_daily_branch_sales_has_one_version_per_pos_transaction

    Checks: no branch-day in fct_daily_branch_sales includes a POS (point of sale) transaction
    that has more than one version. Returns one row per affected branch-day, with how many
    till rows are affected.

    Why: a till can resend a transaction ID with different values (a correction, or a void that
    reuses the ID). Which version counts has not been decided, so fct_daily_branch_sales leaves
    its totals null for that branch-day. This test reports when that happens.
    Severity warn: it flags incoming data that needs a business decision. It must not stop the
    build.
*/

{{ config(severity = 'warn') }}

select
    branch_id,
    sale_date,
    pos_repeated_transaction_row_count
from {{ ref('fct_daily_branch_sales') }}
where pos_repeated_transaction_row_count > 0
