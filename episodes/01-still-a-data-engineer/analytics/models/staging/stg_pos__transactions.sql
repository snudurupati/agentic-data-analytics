-- Point of sale (POS) transactions, one row per transaction_id.
--
-- INCREMENTAL PATTERN: append only, pruned by batch (see _staging.yml)
--
-- WHY THE WATERMARK IS `>=` AND NOT `>`
--
-- This is the difference between a working load and a silently incomplete one.
-- Tills push per branch, so one night can produce several files:
-- transaction_20260722_b.csv is a 28 row supplement from BR03 that arrived
-- after the main file for the same night. Both share a batch date.
--
-- With `>` that supplement is skipped forever, because its batch is not newer
-- than the last one processed. With `>=` the whole most recent batch is pulled
-- again, the delete+insert replaces the rows already there, and the supplement
-- is picked up. The cost is reprocessing one night. The alternative is losing
-- a branch's sales with no error.
--
-- The same mechanism is what would handle a voided sale returning under an
-- existing transaction_id: the batch is re-read and delete+insert replaces the
-- old version rather than the anti-join on the key silently dropping it.
-- Whether the reversal is the row you want to keep is a separate question, and
-- no void has appeared in the data yet to confirm the shape one would take.

{{ config(
    materialized = 'incremental',
    unique_key = 'transaction_id',
    incremental_strategy = 'delete+insert'
) }}

with source as (

    select
        *,
        -- Anchored to the filename prefix on purpose. A bare eight digit
        -- pattern searches the whole path, so a landing zone mounted under a
        -- directory containing digits would match those instead and collapse
        -- every file into one batch.
        regexp_extract(filename, 'transaction_([0-9]{8})', 1) as batch_date
    from {{ source('pos', 'transaction') }}

),

new_batches as (

    select * from source

    {% if is_incremental() %}
    where batch_date >= (select max(_batch_date) from {{ this }})
    {% endif %}

),

-- Only bites if a transaction_id is ever restated within a reprocessed batch.
-- It has not happened yet, and this is what would absorb it if it did.
deduplicated as (

    select *
    from new_batches
    qualify row_number() over (
        partition by transaction_id
        order by filename desc
    ) = 1

),

current_state as (

    select
        transaction_id,
        branch_id,

        -- Named _local deliberately. This is the branch's own wall clock with
        -- no offset attached, while every other timestamp in the project
        -- carries one. The branch timezone lives only in stg_erp__branches.
        sale_datetime   as sold_at_local,

        -- Written by the till, not by us. Fine for freshness, not something to
        -- build correctness on, which is why the watermark above uses the
        -- batch date rather than this.
        received_at,

        sale_amount,
        cost_amount,
        item_count,
        batch_date      as _batch_date,
        filename        as _source_file

    from deduplicated

)

select
    current_state.*,
    {{ audit_columns() }}

from current_state
{% if is_incremental() %}
left join {{ this }} as prior
    on current_state.transaction_id = prior.transaction_id
{% endif %}
