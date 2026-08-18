# plug-dbt

A dbt project configured for Snowflake.

## Prerequisites

- A Snowflake account and development role, database, warehouse, and schema
- A dbt CLI with Snowflake support (dbt Fusion or `dbt-snowflake`)

## Configure

Create the Snowflake resources in a Snowsight SQL worksheet:

```sql
use role sysadmin;

create warehouse if not exists plug_dbt_wh
  warehouse_size = 'XSMALL'
  auto_suspend = 60
  auto_resume = true
  initially_suspended = true;

create database if not exists plug_dbt_dev;
create schema if not exists plug_dbt_dev.dbt_dev;
```

Create the environment file and install the dbt profile:

```sh
cp .env.example .env
cp profiles.yml.example ~/.dbt/profiles.yml
```

Fill in the new account identifier, username, and password in `.env`, keeping each value inside single quotes. Load the variables before starting dbt or Wizard:

```sh
set -a
source .env
set +a
```

The local `.env` file is ignored by Git. The password is referenced from the environment and is not stored in `~/.dbt/profiles.yml`.

## Synthetic seed fixtures

The files in `seeds/` are fictional, version-controlled inputs for practicing dbt—not a production ingestion pattern:

- `raw_valuation_requests.csv`: one delivered valuation request per row
- `raw_offer_events.csv`: one physical delivery of a claimed immutable offer event per row

The fixtures link on `request_id`. Treat them as raw evidence: do not repair or deduplicate the CSVs in place. Build downstream models with `ref()`, preserving source fields, identifiers, units, timestamp semantics, and provenance while adding normalized derivatives. VIN-like values are observations, not universal vehicle identifiers; synthetic contact fields should not flow into governed outputs.

## Validate and run

```sh
dbt debug
dbt build
```

The starter `stg_example` model is materialized as a view and includes `not_null` and `unique` tests. `dbt build` also loads the seed fixtures.
