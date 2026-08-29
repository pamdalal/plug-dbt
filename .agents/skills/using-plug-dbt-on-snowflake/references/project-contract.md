# plug_dbt project contract

Use this reference as a baseline, then re-read the repository because the
project can evolve.

## Project shape

- Project and profile name: `plug_dbt`.
- Adapter target: Snowflake.
- Model layers: `models/staging/` and `models/intermediate/`.
- Seed root: `seeds/`.
- Staging materialization default: incremental.
- Intermediate materialization default: view.
- Every model SQL file has a same-base-name YAML file.
- No package dependency is established.
- `fct_vehicle_lifecycle` is intentionally absent as the candidate exercise.

## Four synthetic raw sources

The CSVs were copied byte-for-byte from clean `plug-tech-screen` commit
`24fc26b1539754f15c18e9f8fc43f200f55ecc49`.

| Seed | Physical grain | Fixed source system |
| --- | --- | --- |
| `raw_valuation_requests` | One immutable request delivery | `valuation_portal` |
| `raw_vehicle_assessments` | One assessment-version or unsupported-envelope delivery | `vehicle_assessment` |
| `raw_offer_events` | One claimed immutable offer-event delivery | `offer_service` |
| `raw_marketplace_events` | One typed immutable marketplace-event delivery | `dealer_marketplace` |

Every source carries `source_record_id`, `source_system`, `source_batch_id`,
lexical `schema_version`, `synthetic_vin`, `request_id`,
`source_updated_at`, and `ingested_at`. The physical key is
`(source_system, source_record_id)`.

Every seed column is explicitly loaded as Snowflake `VARCHAR` with
`quote_columns: false`. Never repair, infer types, or deduplicate at the seed
boundary.

## Staging contract

Each `stg_*` model:

- remains one row per physical delivery;
- explicitly uses incremental append materialization;
- never configures `unique_key` or merge behavior;
- retains every raw field and delivery identifier;
- adds a deterministic namespaced `delivery_sk`;
- adds explicit `TIMESTAMP_TZ` derivatives;
- uses exact fixed-point numeric derivatives;
- exposes explicit odometer or amount normalization fields;
- keeps warning/normalization flags separate from disposition;
- uses parsed `ingested_at` with a strict greater-than watermark; and
- loads all rows when the existing maximum watermark is null.

Equal-watermark and earlier deliveries are exposed by reverse completeness
tests rather than silently replayed.

## Disposition and canonical inputs

The four source-specific disposition models derive:

- supported-schema and row-contract checks;
- source-specific immutable replay groups and complete payload comparison;
- deterministic survivors ordered by parsed `ingested_at` and
  `source_record_id`;
- request and synthetic-VIN relationships;
- point-in-time pricing-assessment availability; and
- supported marketplace confirmation transitions.

Every physical delivery receives exactly one `accepted`, `duplicate`, or
`quarantined` disposition. `int_delivery_dispositions` exposes source,
delivery key, request ID, disposition, reason, and survivor delivery key. The
four `int_canonical_*` views contain accepted survivors only.

Do not hardcode finding IDs, expected rows, survivor maps, disposition totals,
latent values, or lifecycle answers.

## Candidate lifecycle boundary

The future `fct_vehicle_lifecycle` pair has one row per `request_id` and the
13-column contract documented in `README.md` and `docs/migration.md`. The
candidate owns point-in-time assessment selection, current offer-version
selection, marketplace reconstruction, request-grain fan-in, lifecycle and
label classification, focused tests, reconciliation, and bounded analysis.

## YAML and tests

- List every final-select column alphabetically.
- Give every output column a meaningful description and contract-backed test.
- Use native generic tests first, project-local generic tests second, and
  focused singular SQL tests for asymmetric reconciliation.
- Profile every loaded column in the confirmed development target before
  claiming warehouse validation is complete.
- Preserve imperfect evidence through disposition rather than weakening tests
  or repairing source rows.

## Profile and safety

`profiles.yml.example` reads:

- `DBT_SNOWFLAKE_ACCOUNT`
- `DBT_SNOWFLAKE_USER`
- `DBT_ENV_SECRET_SNOWFLAKE_PASSWORD`
- `DBT_SNOWFLAKE_ROLE`
- `DBT_SNOWFLAKE_DATABASE`
- `DBT_SNOWFLAKE_WAREHOUSE`
- `DBT_SNOWFLAKE_SCHEMA`

The schema fallback is `DBT_MIGRATION`, but warehouse work must still confirm
an explicitly intended pre-created non-production schema. Never expose secret
values, run direct Snowflake DDL, use an unscoped build, or run
`--full-refresh` without explicit approval.
