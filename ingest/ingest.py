"""
Pulls public repos, commits, pull requests, and issues for one GitHub
account into a Postgres `raw` schema. Idempotent — every table is upserted
on its natural key, so re-running is always safe (a scheduled re-run just
refreshes anything that changed).

Env vars:
  DATABASE_URL     Postgres connection string
  GITHUB_TOKEN     optional but recommended (60/hr -> 5,000/hr rate limit)
  GITHUB_USERNAME  account whose public repos get ingested
"""

import os
import sys
import time
from datetime import datetime, timezone

import psycopg2
import psycopg2.extras
import requests
from dotenv import load_dotenv

load_dotenv()

GITHUB_API = "https://api.github.com"
DATABASE_URL = os.environ["DATABASE_URL"]
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")
GITHUB_USERNAME = os.environ["GITHUB_USERNAME"]

HEADERS = {"accept": "application/vnd.github+json"}
if GITHUB_TOKEN:
    HEADERS["authorization"] = f"Bearer {GITHUB_TOKEN}"


def get_paginated(url: str, params: dict | None = None) -> list[dict]:
    """Follows GitHub's Link-header pagination until exhausted. Backs off
    once on a rate-limit response rather than failing the whole run."""
    items: list[dict] = []
    params = dict(params or {})
    params.setdefault("per_page", 100)
    next_url: str | None = url

    while next_url:
        res = requests.get(next_url, headers=HEADERS, params=params if next_url == url else None)
        if res.status_code == 403 and "rate limit" in res.text.lower():
            reset_at = int(res.headers.get("x-ratelimit-reset", time.time() + 60))
            wait = max(0, reset_at - int(time.time())) + 1
            print(f"rate limited, sleeping {wait}s", file=sys.stderr)
            time.sleep(wait)
            continue
        res.raise_for_status()
        items.extend(res.json())
        next_url = res.links.get("next", {}).get("url")

    return items


def fetch_repos() -> list[dict]:
    return get_paginated(f"{GITHUB_API}/users/{GITHUB_USERNAME}/repos", {"type": "owner"})


def fetch_commits(full_name: str) -> list[dict]:
    try:
        return get_paginated(f"{GITHUB_API}/repos/{full_name}/commits")
    except requests.HTTPError:
        return []  # empty repo (409) or other per-repo failure — skip, don't fail the run


def fetch_pull_requests(full_name: str) -> list[dict]:
    try:
        return get_paginated(f"{GITHUB_API}/repos/{full_name}/pulls", {"state": "all"})
    except requests.HTTPError:
        return []


def fetch_issues(full_name: str) -> list[dict]:
    try:
        return get_paginated(f"{GITHUB_API}/repos/{full_name}/issues", {"state": "all"})
    except requests.HTTPError:
        return []


def upsert(cur, table: str, key: str, rows: list[dict]):
    if not rows:
        return
    columns = list(rows[0].keys())
    updates = ", ".join(f"{c} = excluded.{c}" for c in columns if c != key)
    query = f"""
        insert into raw.{table} ({", ".join(columns)})
        values %s
        on conflict ({key}) do update set {updates}
    """
    values = [tuple(row[c] for c in columns) for row in rows]
    psycopg2.extras.execute_values(cur, query, values)


def main():
    fetched_at = datetime.now(timezone.utc)
    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = False

    try:
        with conn.cursor() as cur:
            repos = fetch_repos()
            print(f"found {len(repos)} public repos for {GITHUB_USERNAME}")

            upsert(
                cur,
                "repos",
                "id",
                [
                    {
                        "id": r["id"],
                        "name": r["name"],
                        "full_name": r["full_name"],
                        "language": r.get("language"),
                        "stargazers_count": r.get("stargazers_count", 0),
                        "created_at": r.get("created_at"),
                        "updated_at": r.get("updated_at"),
                        "fetched_at": fetched_at,
                    }
                    for r in repos
                ],
            )

            for repo in repos:
                full_name = repo["full_name"]

                commits = fetch_commits(full_name)
                upsert(
                    cur,
                    "commits",
                    "sha",
                    [
                        {
                            "sha": c["sha"],
                            "repo_full_name": full_name,
                            "author_name": (c.get("commit", {}).get("author") or {}).get("name"),
                            "message": c.get("commit", {}).get("message", "").split("\n")[0],
                            "committed_at": (c.get("commit", {}).get("author") or {}).get("date"),
                            "fetched_at": fetched_at,
                        }
                        for c in commits
                        if c.get("commit")
                    ],
                )

                prs = fetch_pull_requests(full_name)
                upsert(
                    cur,
                    "pull_requests",
                    "id",
                    [
                        {
                            "id": p["id"],
                            "repo_full_name": full_name,
                            "number": p["number"],
                            "state": p["state"],
                            "title": p["title"],
                            "created_at": p["created_at"],
                            "merged_at": p.get("merged_at"),
                            "closed_at": p.get("closed_at"),
                            "fetched_at": fetched_at,
                        }
                        for p in prs
                    ],
                )

                issues = fetch_issues(full_name)
                # The issues endpoint also returns pull requests — a PR
                # carries a "pull_request" key that a true issue never has.
                real_issues = [i for i in issues if "pull_request" not in i]
                upsert(
                    cur,
                    "issues",
                    "id",
                    [
                        {
                            "id": i["id"],
                            "repo_full_name": full_name,
                            "number": i["number"],
                            "state": i["state"],
                            "title": i["title"],
                            "created_at": i["created_at"],
                            "closed_at": i.get("closed_at"),
                            "fetched_at": fetched_at,
                        }
                        for i in real_issues
                    ],
                )

                print(
                    f"  {full_name}: {len(commits)} commits, {len(prs)} PRs, {len(real_issues)} issues"
                )

        conn.commit()
        print("done")
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
