{#
    The two audit columns every table carries, per CONVENTIONS.md.

    inserted_ts  when we first loaded this row
    updated_ts   when we last wrote it

    Both are stamped by us at load time rather than taken from a source column,
    because a source timestamp records when the source thinks something
    changed, and these record when we actually saw it. That is the difference
    that matters when a number looks wrong.

    On a first run or a full refresh there is no prior table to read, so both
    columns are the current run's timestamp. On an incremental run the model
    left joins its own existing rows as `prior`, and inserted_ts is carried
    forward so it keeps meaning "first seen" rather than resetting every time
    the row is rewritten.

    Because the incremental strategy is delete+insert, only rows in the
    incoming batch are rewritten, so updated_ts moves only for rows that were
    actually reprocessed.

    Requires the calling model to alias its existing rows as `prior` inside an
    `{% if is_incremental() %}` block. There is one caller per staging model
    and they all follow the same shape.
#}

{% macro audit_columns() %}
    {%- if is_incremental() -%}
    coalesce(prior.inserted_ts, current_timestamp) as inserted_ts,
    {%- else -%}
    current_timestamp                              as inserted_ts,
    {%- endif %}
    current_timestamp                              as updated_ts
{% endmacro %}
