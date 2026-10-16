/*
    assert_order_total_equals_sum_of_lines

    Checks: for each order in fct_order that is not deleted, order_total_amount equals the sum
    of line_amount over its lines in fct_order_line that are not deleted. An order with no
    such lines also fails. Returns one row per order that does not match.

    Why: REQUIREMENTS.md says an order has one header and one or more lines, and STANDARDS.md
    says two numbers that should reconcile get a test.
    Severity warn: both numbers come straight from the ERP (Enterprise Resource Planning) feed.
    A mismatch is incoming data to review, not a fault in this build, and it must not stop the
    reports that depend on these tables.
*/

{{ config(severity = 'warn') }}

with line_totals as (

    select
        order_number,
        sum(line_amount) as sum_of_line_amounts
    from {{ ref('fct_order_line') }}
    where not is_deleted
    group by order_number

)

select
    fct_order.order_number,
    fct_order.order_total_amount,
    line_totals.sum_of_line_amounts
from {{ ref('fct_order') }} as fct_order
left join line_totals
    on fct_order.order_number = line_totals.order_number
where not fct_order.is_deleted
  and fct_order.order_total_amount is distinct from line_totals.sum_of_line_amounts
