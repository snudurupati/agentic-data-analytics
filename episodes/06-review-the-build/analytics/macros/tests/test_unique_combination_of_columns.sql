{#
    Generic test: no two rows share the same values across the listed columns.

    This is the uniqueness test on the grain that STANDARDS.md requires. It returns one row for
    each duplicated combination, so a failure shows exactly which combinations repeat.

    Usage, on a model:
        data_tests:
          - unique_combination_of_columns:
              arguments:
                combination_of_columns: [branch_id, change_ts]
#}
{% test unique_combination_of_columns(model, combination_of_columns) %}

select
    {{ combination_of_columns | join(', ') }},
    count(*) as row_count
from {{ model }}
group by {{ combination_of_columns | join(', ') }}
having count(*) > 1

{% endtest %}
