select
    id as issue_id,
    repo_full_name,
    number as issue_number,
    state as issue_state,
    title as issue_title,
    created_at::timestamptz as issue_created_at,
    closed_at::timestamptz as issue_closed_at
from {{ source('raw', 'issues') }}
