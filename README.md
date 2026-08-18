# plug-dbt

A dbt project configured for Snowflake.

## Prerequisites

- A Snowflake account and development role, database, warehouse, and schema
- A dbt CLI with Snowflake support (dbt Fusion or `dbt-snowflake`)

## Configure

Create local configuration files from the committed templates:

```sh
cp .env.example .env
cp profiles.yml.example profiles.yml
```

Fill in `.env`, keeping each value inside single quotes, then load the variables into your shell:

```sh
set -a
source .env
set +a
```

Both `.env` and `profiles.yml` are ignored by Git.

## Validate and run

```sh
dbt debug --profiles-dir .
dbt build --profiles-dir .
```

The starter `stg_example` model is materialized as a view and includes `not_null` and `unique` tests.
