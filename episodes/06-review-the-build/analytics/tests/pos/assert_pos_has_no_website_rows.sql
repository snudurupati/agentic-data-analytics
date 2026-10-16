/*
    assert_pos_has_no_website_rows

    Checks: no POS (point of sale) row carries the website's branch_id. Returns the offending
    rows.

    Why: CONVENTIONS.md says the POS feed covers the physical tills only. Web orders reach us
    through the ERP (Enterprise Resource Planning) order feed and never appear here. A website
    row in this feed would count a web sale twice. This is incoming data breaking a rule, so the
    test warns.

    How: the website is the branch in stg_erp__branches with no city (CONVENTIONS.md: it has no
    city because there is no building). Any version of the branch row counts.
*/

{{ config(severity = 'warn') }}

select
    transactions.branch_id,
    transactions.transaction_id,
    transactions.sale_local_ts,
    transactions.source_file_name
from {{ ref('stg_pos__transactions') }} as transactions
where transactions.branch_id in (
    select branch_id
    from {{ ref('stg_erp__branches') }}
    where city is null
)
