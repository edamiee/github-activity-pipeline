select
    p.pr_id,
    p.repo_full_name,
    r.repo_id,
    p.pr_number,
    p.pr_state,
    p.pr_title,
    p.pr_created_at,
    p.pr_merged_at,
    p.pr_closed_at,
    p.is_merged,
    p.pr_created_at::date as created_date,
    case
        when p.pr_merged_at is not null
            then extract(epoch from (p.pr_merged_at - p.pr_created_at)) / 3600.0
    end as cycle_time_hours
from {{ ref('stg_github__pull_requests') }} as p
left join {{ ref('stg_github__repos') }} as r
    on p.repo_full_name = r.repo_full_name
