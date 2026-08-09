-- Calendar spine from the earliest commit on record to today, so every
-- metric can be plotted with a consistent, gap-free time axis rather than
-- only showing days that happened to have activity. Plain generate_series
-- with the bounds inlined as scalar subqueries — simpler and more portable
-- than a macro-generated date spine, and avoids relying on a sibling CTE
-- being visible inside a macro's own generated SQL.
with spine as (
    select generate_series(
        (select coalesce(min(committed_at::date), current_date) from {{ ref('stg_github__commits') }}),
        current_date,
        interval '1 day'
    )::date as date_day
)

select
    date_day,
    extract(isoyear from date_day)::int as iso_year,
    extract(week from date_day)::int as iso_week,
    extract(month from date_day)::int as month_of_year,
    extract(dow from date_day)::int as day_of_week,
    to_char(date_day, 'Day') as day_name
from spine
