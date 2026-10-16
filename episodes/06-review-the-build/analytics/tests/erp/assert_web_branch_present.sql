-- The branch list includes the website as branch WEB (CONVENTIONS.md: we count the website as a
-- branch; REQUIREMENTS.md: the website is a branch).
-- Returns one row when no WEB branch row exists.

{{ config(severity = 'warn') }}

select 'WEB' as missing_branch_id
where not exists (
    select 1
    from {{ ref('stg_erp__branches') }}
    where branch_id = 'WEB'
)
