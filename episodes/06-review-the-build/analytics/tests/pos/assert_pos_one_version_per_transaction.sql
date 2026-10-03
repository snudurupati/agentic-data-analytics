/*
    assert_pos_one_version_per_transaction

    Checks: each (branch_id, transaction_id) has only one version in stg_pos__transactions.
    Returns one row per pair with more than one version.

    Why: CONVENTIONS.md says some tills send a zero-amount row that reuses the original
    transaction ID for a void, and the POS (point of sale) feed carries corrections. Either one
    gives the same transaction ID a second, different row. Staging keeps both. Which row
    counts is a business decision nobody has made yet, so a repeated ID is reported with a
    warning and not treated as an error.

    How: transaction IDs are not unique across branches, so the pair includes branch_id.
*/

{{ config(severity = 'warn') }}

select
    branch_id,
    transaction_id,
    count(*) as version_count
from {{ ref('stg_pos__transactions') }}
group by branch_id, transaction_id
having count(*) > 1
