select
    id as pr_id,
    repo_full_name,
    number as pr_number,
    state as pr_state,
    title as pr_title,
    created_at::timestamptz as pr_created_at,
    merged_at::timestamptz as pr_merged_at,
    closed_at::timestamptz as pr_closed_at,
    (merged_at is not null) as is_merged
from {{ source('raw', 'pull_requests') }}
