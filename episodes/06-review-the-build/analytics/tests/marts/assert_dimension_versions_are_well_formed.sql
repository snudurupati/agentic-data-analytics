/*
    assert_dimension_versions_are_well_formed

    Checks, for dim_branch, dim_product and dim_customer:
      - each business key has exactly one current version (is_current true);
      - each version ends after it begins (valid_to_ts later than valid_from_ts);
      - each closed version ends exactly where the next version of the same key begins, so
        the versions of a key have no gaps and no overlaps.
    Returns one row per business key that breaks one of these.

    Why: a fact looks up the version valid at the time of the event. That only works when the
    versions of a key never overlap.
    Severity error: a failure means the dimension is built wrong.
*/

with versions as (

    select 'dim_branch' as dimension, branch_id as business_key, valid_from_ts, valid_to_ts, is_current
    from {{ ref('dim_branch') }}
    union all
    select 'dim_product', product_id, valid_from_ts, valid_to_ts, is_current
    from {{ ref('dim_product') }}
    union all
    select 'dim_customer', customer_number, valid_from_ts, valid_to_ts, is_current
    from {{ ref('dim_customer') }}

),

with_next as (

    select
        *,
        lead(valid_from_ts) over (
            partition by dimension, business_key
            order by valid_from_ts
        ) as next_valid_from_ts
    from versions

)

select
    dimension,
    business_key,
    count(*) filter (where is_current) as current_version_count,
    count(*) filter (where valid_to_ts <= valid_from_ts) as backwards_version_count,
    count(*) filter (where valid_to_ts is distinct from next_valid_from_ts) as gap_or_overlap_count
from with_next
group by dimension, business_key
having count(*) filter (where is_current) <> 1
    or count(*) filter (where valid_to_ts <= valid_from_ts) > 0
    or count(*) filter (where valid_to_ts is distinct from next_valid_from_ts) > 0
