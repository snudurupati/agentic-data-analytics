{#
    The two audit columns every table in the warehouse carries (STANDARDS.md).

    inserted_ts and updated_ts are written at load time, as timestamps with a time zone.
    Every model here is rebuilt in full on each run, so both hold the time of the run that
    built the row.

    Usage, as the last line of a select list: {{ audit_columns() }}
#}
{% macro audit_columns() %}
    current_timestamp as inserted_ts,
    current_timestamp as updated_ts
{% endmacro %}
