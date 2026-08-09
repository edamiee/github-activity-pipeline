select
    c.commit_sha,
    c.repo_full_name,
    r.repo_id,
    r.language,
    c.author_name,
    c.commit_message,
    c.committed_at,
    c.committed_at::date as committed_date
from {{ ref('stg_github__commits') }} as c
left join {{ ref('stg_github__repos') }} as r
    on c.repo_full_name = r.repo_full_name
