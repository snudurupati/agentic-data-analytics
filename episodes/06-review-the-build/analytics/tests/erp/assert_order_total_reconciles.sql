-- An order header total equals the sum of its line amounts (REQUIREMENTS.md: an order has one
-- header and one or more lines; STANDARDS.md: two numbers that should reconcile get a test).
-- The comparison uses the latest version of each header and of each line, and leaves out
-- versions that are deletes.
-- Returns one row per order whose total does not match its lines.

{{ config(severity = 'warn') }}

with latest_headers as (

    select order_number, order_total_amount
    from {{ ref('stg_erp__order_headers') }}
    qualify row_number() over (partition by order_number order by change_ts desc) = 1
        and not is_deleted

),

latest_lines as (

    select order_number, line_amount
    from {{ ref('stg_erp__order_lines') }}
    qualify row_number() over (partition by order_number, line_number order by change_ts desc) = 1
        and not is_deleted

),

line_totals as (

    select order_number, sum(line_amount) as sum_of_line_amounts
    from latest_lines
    group by order_number

)

select
    latest_headers.order_number,
    latest_headers.order_total_amount,
    line_totals.sum_of_line_amounts
from latest_headers
left join line_totals
    on latest_headers.order_number = line_totals.order_number
where line_totals.sum_of_line_amounts is null
   or latest_headers.order_total_amount <> line_totals.sum_of_line_amounts
