select
    repo_id,
    repo_name,
    repo_full_name,
    language,
    stargazers_count,
    repo_created_at,
    repo_updated_at
from {{ ref('stg_github__repos') }}
