/*
    assert_no_deleted_order

    Checks: no order or order line in the reports has a delete (op D) as its latest version.
    Returns one row per deleted order and one per deleted line.

    Why: the ERP (Enterprise Resource Planning) feed can delete an order, and CONVENTIONS.md
    says we never delete, but nothing says how a deleted order affects revenue. The reports
    keep deleted orders with is_deleted true, and fct_daily_branch_sales leaves its totals null
    for the affected branch-day. This test reports when that happens.
    Severity warn: it flags incoming data that needs a business decision. It must not stop the
    build.
*/

{{ config(severity = 'warn') }}

select
    'order' as deleted_record,
    order_number,
    cast(null as integer) as line_number,
    branch_id,
    order_date
from {{ ref('fct_order') }}
where is_deleted

union all

select
    'order line',
    order_number,
    line_number,
    branch_id,
    order_date
from {{ ref('fct_order_line') }}
where is_deleted
