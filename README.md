# github-activity-pipeline

A real ingest → transform → semantic-layer → BI pipeline, built to demonstrate
data engineering practice rather than just display data. It ingests GitHub
activity (commits, pull requests, issues) across a set of public repos,
models it with dbt (staging → marts → a dbt Semantic Layer), and exposes the
result through an open-source BI tool.

This is a companion project to [damienkedwards.tech](https://damienkedwards.tech)
— the story behind it is written up in the site's build log, and it's linked
from the gated [`/projects`](https://damienkedwards.tech/projects) page.

## Architecture

```
GitHub REST API
      │  ingest/ingest.py  (Python, scheduled via GitHub Actions)
      ▼
Postgres — raw schema (repos, commits, pull_requests, issues)
      │  dbt: staging → marts
      ▼
Postgres — marts schema (dim_repos, dim_dates, fct_commits, fct_pull_requests, fct_issues)
      │  dbt Semantic Layer (semantic_models + metrics)
      ▼
Lightdash — dashboards, exploration
```

**Why this shape:** the ingest step is intentionally dumb (pull, upsert,
done) — all the actual logic (dedup, typing, business rules, metric
definitions) lives in dbt, where it's version-controlled, tested, and
documented as SQL/YAML rather than buried in a script. The semantic layer
is what makes the BI layer coherent: Lightdash reads the same metric
definitions dbt defines, so "commits per week" means the same thing in a
dashboard as it does in a `dbt test`.

## Metrics (the semantic layer)

Defined once in `dbt/models/semantic_models/`, queryable from dbt (`dbt sl
query`) or from Lightdash:

| Metric | What it measures |
|---|---|
| `commits_per_week` | Commit volume over time, by repo |
| `active_repos` | Distinct repos with at least one commit in a period |
| `pr_merge_rate` | Share of pull requests that end up merged vs. closed unmerged |
| `avg_pr_cycle_time` | Average time from PR opened to merged |
| `issue_close_rate` | Share of issues closed vs. opened in a period |
| `avg_time_to_close` | Average time from issue opened to closed |

## Repo layout

```
ingest/                     Python ingestion script — GitHub API -> Postgres raw schema
dbt/
  models/staging/           1:1 typed views over the raw tables
  models/marts/             dim_repos, dim_dates, fct_commits, fct_pull_requests, fct_issues
  models/semantic_models/   metric + dimension definitions (the semantic layer)
.github/workflows/          scheduled ingest + dbt run/test
```

## Setup

1. **Database**: a Postgres schema to land data in (this project assumes a
   dedicated schema, e.g. `github_pipeline`, in an existing Postgres
   instance — doesn't need its own database).
   ```sql
   create schema if not exists raw;
   create schema if not exists marts;
   ```
2. **Environment variables** (local dev — copy into a `.env` in `ingest/`,
   never commit it):
   - `DATABASE_URL` — Postgres connection string, used by the ingest script
   - `GITHUB_TOKEN` — a GitHub personal access token with `public_repo` read
     access (raises the API rate limit from 60/hr to 5,000/hr; ingestion
     still works without one, just slower)
   - `GITHUB_USERNAME` — the account whose public repos get ingested

   dbt's Postgres adapter wants discrete connection fields rather than one
   URL — `~/.dbt/profiles.yml` (see `dbt/profiles_example.yml`) reads
   `PGHOST` / `PGUSER` / `PGPASSWORD` / `PGDATABASE` from the environment,
   pointing at the same instance as `DATABASE_URL` above.

   In GitHub Actions (`.github/workflows/pipeline.yml`), the equivalents are
   repo **secrets** `DATABASE_URL`, `PIPELINE_GITHUB_TOKEN`, `PGPASSWORD`,
   and repo **variables** `INGEST_GITHUB_USERNAME`, `PGHOST`, `PGUSER`,
   `PGDATABASE`. Both `PIPELINE_GITHUB_TOKEN` and `INGEST_GITHUB_USERNAME`
   avoid the `GITHUB_` prefix — GitHub rejects secrets *and* variables
   starting with it, since that namespace is reserved for the values
   Actions injects automatically for the runner itself.
3. **Ingest locally**:
   ```bash
   cd ingest
   pip install -r requirements.txt
   python ingest.py
   ```
4. **dbt**: create `~/.dbt/profiles.yml` (see `dbt/profiles_example.yml` for
   the shape — this file holds credentials, never commit a real one) and run:
   ```bash
   cd dbt
   dbt run
   dbt test
   ```
   No external packages required — everything's plain SQL/Jinja and dbt's
   built-in Semantic Layer, so there's no `dbt deps` step.
5. **Lightdash**: point a self-hosted Lightdash instance at this same
   Postgres connection and the `dbt/` project directory — it reads the
   semantic models directly, no separate dashboard config needed for the
   metrics themselves. See [Lightdash's self-hosting docs](https://docs.lightdash.com/self-host/)
   for deployment (Railway/Render/Fly.io/Docker all work).

## Scheduling

`.github/workflows/pipeline.yml` runs the ingest script and a full
`dbt run && dbt test` on a daily schedule via GitHub Actions — set the
secrets and variables listed above (Settings → Secrets and variables →
Actions) for it to work. `workflow_dispatch` is also enabled, so it can be
triggered manually from the Actions tab without waiting for the schedule.

## Status

Scaffold stage — ingestion script and dbt models are real and runnable
against a Postgres instance; Lightdash hosting and the first live dashboard
are the next step.
