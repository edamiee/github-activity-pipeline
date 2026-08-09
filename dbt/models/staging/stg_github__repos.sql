-- One row per public repo. Typed pass-through — no business logic here,
-- that belongs downstream in marts.
select
    id as repo_id,
    name as repo_name,
    full_name as repo_full_name,
    language,
    stargazers_count,
    created_at::timestamptz as repo_created_at,
    updated_at::timestamptz as repo_updated_at
from {{ source('raw', 'repos') }}
