{#
    Generic test: the columns a source delivers match the columns we expect.

    A source reads every file in its folder by column name, so a new column or a missing one does
    not stop the read (STANDARDS.md). This test is how the change gets reported. It returns one
    row per difference: a column we expected and did not receive, or a column we received and
    did not expect.

    Usage, on a source table:
        data_tests:
          - source_columns_match:
              arguments:
                expected_columns: [branch_id, branch_name, op, change_ts, _ingested_at, filename]
#}
{% test source_columns_match(model, expected_columns) %}

with received as (
    select column_name
    from (describe select * from {{ model }})
),

expected as (
    select unnest([
        {%- for column_name in expected_columns %}
        '{{ column_name }}'{% if not loop.last %},{% endif %}
        {%- endfor %}
    ]) as column_name
)

select 'missing' as difference, column_name
from expected
where column_name not in (select column_name from received)

union all

select 'unexpected' as difference, column_name
from received
where column_name not in (select column_name from expected)

{% endtest %}
