{% test expected_source_columns(model, column_names) %}

{#
    A source's external_location reads with union_by_name=true, so a new or
    missing column doesn't break the pipeline, it just gets backfilled with
    nulls or dropped silently. This test is what turns that silence back into
    something visible: it fails, without stopping the run, when the source's
    actual columns no longer match the column_names declared for it here.
#}

with actual as (
    select * from (describe select * from {{ model }})
),

expected as (
    select unnest(array[
        {% for column_name in column_names %}
        '{{ column_name }}'{{ "," if not loop.last }}
        {% endfor %}
    ]) as column_name
)

select column_name, 'missing from source' as issue
from expected
where column_name not in (select column_name from actual)

union all

select column_name, 'not declared in sources.yml' as issue
from actual
where column_name not in (select column_name from expected)

{% endtest %}
