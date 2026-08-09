{#
  Without this override, dbt concatenates a model's custom +schema config
  onto the profile's default schema (e.g. profile schema "raw" + model
  +schema "staging" -> "raw_staging"). pipeline_writer only has CREATE on
  the exact schemas raw/staging/marts, not their concatenated forms, so
  the default behavior fails with "permission denied for database
  postgres" the moment dbt tries to auto-create one that doesn't exist.
  This makes a model's custom schema exactly what's configured, no prefix.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
