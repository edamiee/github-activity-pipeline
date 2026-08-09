select
    sha as commit_sha,
    repo_full_name,
    author_name,
    message as commit_message,
    committed_at::timestamptz as committed_at
from {{ source('raw', 'commits') }}
where committed_at is not null
