-- An update or delete to an order arrives within fourteen days of the order (CONVENTIONS.md: a
-- period stays open for fourteen days; anything after that is an exception, not a correction).
-- Only U (update) and D (delete) rows are checked. Most I (insert) rows come from the first
-- delivery of the feed on 20 July 2026, which loaded orders going back to January.
-- The window is measured as fourteen days of elapsed time from order_ts to change_ts.
-- Returns one row per order header change that arrived after the window.

{{ config(severity = 'warn') }}

select
    order_number,
    op,
    order_ts,
    change_ts
from {{ ref('stg_erp__order_headers') }}
where op in ('U', 'D')
  and change_ts > order_ts + interval 14 days
