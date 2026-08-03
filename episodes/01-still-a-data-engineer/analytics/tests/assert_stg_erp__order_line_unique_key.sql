select order_number, line_number, count(*) as row_count
from {{ ref('stg_erp__order_line') }}
group by order_number, line_number
having count(*) > 1
