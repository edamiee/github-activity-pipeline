select
    i.issue_id,
    i.repo_full_name,
    r.repo_id,
    i.issue_number,
    i.issue_state,
    i.issue_title,
    i.issue_created_at,
    i.issue_closed_at,
    i.issue_created_at::date as created_date,
    case
        when i.issue_closed_at is not null
            then extract(epoch from (i.issue_closed_at - i.issue_created_at)) / 3600.0
    end as time_to_close_hours
from {{ ref('stg_github__issues') }} as i
left join {{ ref('stg_github__repos') }} as r
    on i.repo_full_name = r.repo_full_name
