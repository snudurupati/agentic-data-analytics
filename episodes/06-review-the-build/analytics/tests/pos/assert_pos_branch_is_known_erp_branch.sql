/*
    assert_pos_branch_is_known_erp_branch

    Checks: every branch_id in the POS (point of sale) feed exists in stg_erp__branches, the ERP
    (Enterprise Resource Planning) branch list. Returns one row per unknown branch_id.

    Why: every sale is reported by branch, and the branch list comes from ERP. A POS branch_id
    that ERP has never sent cannot be placed in a report. This is a key test, so it errors.

    How: a branch_id matches if any row for it exists in stg_erp__branches, whatever its
    change_ts or op.
*/

select
    transactions.branch_id,
    count(*) as row_count
from {{ ref('stg_pos__transactions') }} as transactions
where transactions.branch_id not in (
    select branch_id from {{ ref('stg_erp__branches') }}
)
group by transactions.branch_id
