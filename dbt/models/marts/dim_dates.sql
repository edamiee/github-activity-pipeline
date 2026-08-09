-- Calendar spine from the earliest commit on record to today, so every
-- metric can be plotted with a consistent, gap-free time axis rather than
-- only showing days that happened to have activity.
with bounds as (
    select
        coalesce(min(committed_at::date), current_date) as start_date,
        current_date as end_date
    from {{ ref('stg_github__commits') }}
),

spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="(select start_date from bounds)",
        end_date="(select end_date + 1 from bounds)"
    ) }}
)

select
    date_day::date as date_day,
    extract(isoyear from date_day)::int as iso_year,
    extract(week from date_day)::int as iso_week,
    extract(month from date_day)::int as month_of_year,
    extract(dow from date_day)::int as day_of_week,
    to_char(date_day, 'Day') as day_name
from spine
