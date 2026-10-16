{#
    Builds a single-column surrogate key from one or more columns.

    Each column is cast to text, a null becomes the marker '_null_', and the values are joined
    with '|' before hashing. The marker and the separator keep ('a', null) and (null, 'a') apart,
    and keep ('ab', 'c') apart from ('a', 'bc').

    Usage: {{ generate_surrogate_key(['branch_id', 'change_ts']) }}

    The project has no package dependencies, so this stands in for the dbt_utils macro of the
    same name.
#}
{% macro generate_surrogate_key(column_names) %}
    md5(
        {%- for column_name in column_names %}
        coalesce(cast({{ column_name }} as varchar), '_null_'){% if not loop.last %} || '|' ||{% endif %}
        {%- endfor %}
    )
{% endmacro %}
