-- Raw landing tables for the GitHub ingestion script. Run once against
-- whatever Postgres instance DATABASE_URL points at before the first
-- `python ingest.py`. dbt's staging models read from these directly.

create schema if not exists raw;

create table if not exists raw.repos (
  id bigint primary key,
  name text not null,
  full_name text not null unique,
  language text,
  stargazers_count integer not null default 0,
  created_at timestamptz,
  updated_at timestamptz,
  fetched_at timestamptz not null
);

create table if not exists raw.commits (
  sha text primary key,
  repo_full_name text not null,
  author_name text,
  message text,
  committed_at timestamptz,
  fetched_at timestamptz not null
);
create index if not exists commits_repo_idx on raw.commits (repo_full_name);
create index if not exists commits_committed_at_idx on raw.commits (committed_at);

create table if not exists raw.pull_requests (
  id bigint primary key,
  repo_full_name text not null,
  number integer not null,
  state text not null,
  title text,
  created_at timestamptz not null,
  merged_at timestamptz,
  closed_at timestamptz,
  fetched_at timestamptz not null
);
create index if not exists pull_requests_repo_idx on raw.pull_requests (repo_full_name);

create table if not exists raw.issues (
  id bigint primary key,
  repo_full_name text not null,
  number integer not null,
  state text not null,
  title text,
  created_at timestamptz not null,
  closed_at timestamptz,
  fetched_at timestamptz not null
);
create index if not exists issues_repo_idx on raw.issues (repo_full_name);
