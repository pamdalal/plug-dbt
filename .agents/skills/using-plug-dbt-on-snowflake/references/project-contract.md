# plug_dbt project contract

Use this reference as a baseline, then re-read the repository because the project can evolve.

## Project shape

- Project and profile name: `plug_dbt`.
- Adapter target: Snowflake.
- Model root: `models/`.
- Seed root: `seeds/`.
- Current modeled layer: `models/staging/`.
- Staging materialization default: `view` from `dbt_project.yml`.
- Current smoke-test model: `stg_example`, documented in `models/staging/_staging.yml`.
- Configured but not necessarily present until needed: `analyses/`, `tests/`, `macros/`, and `snapshots/`.
- No package contract is currently established. Do not assume `dbt_utils` or another package exists.

## Inputs are synthetic raw evidence

The version-controlled CSVs are practice fixtures, not a production ingestion pattern. They are dbt seeds, so reference them with `ref()`.

Treat the loaded Snowflake seed relations—not the CSV quoting—as the executable type boundary. dbt/Snowflake can infer numeric or timestamp types for text that looks numeric or temporal. Inspect loaded column types and representative values before claiming that leading zeros, original timestamp text, source offsets, or formatting were preserved. If lexical preservation is required, propose explicit seed `column_types` configuration and explain the reload impact before changing it.

### `raw_valuation_requests`

The documented grain is one delivered valuation request record per row. Important field groups include:

- delivery/provenance: `source_record_id`, `source_system`, `source_batch_id`, `schema_version`, `source_updated_at`, `ingested_at`;
- request identity: `request_id`;
- submitter/channel: `submitter_type`, `submitter_account_id`, `channel`;
- observations: `vin_like`, `odometer_value`, `odometer_unit`, `postal_code`, `submitted_at`;
- synthetic contact fields: `contact_name`, `contact_email`, `contact_phone`.

Do not claim that `request_id` or any other candidate key is unique until it is profiled.

### `raw_offer_events`

The documented grain is one physical delivery of a claimed immutable offer event per row. Important field groups include:

- delivery/provenance: `source_record_id`, `source_system`, `source_batch_id`, `schema_version`, `source_updated_at`, `ingested_at`;
- event identity and lifecycle: `source_event_id`, `offer_id`, `request_id`, `event_type`, `event_sequence`, `offer_version`, `event_at`;
- value: `offer_amount`, `offer_amount_unit`, `currency_code`;
- lifecycle context: `expires_at`, `reason_code`.

Expect repeated `offer_id` values across lifecycle events and mixed amount units. Do not collapse physical deliveries or choose a winning event without an explicit downstream grain and deterministic ordering policy.

## Evidence-preservation rules

- Never repair, normalize, reorder, or deduplicate the CSV fixtures in place.
- Preserve the values and types available at the loaded seed boundary in staging models; do not claim that unrecoverable CSV lexical formatting survived inference.
- When required semantics cannot survive inferred seed types, propose explicit seed column types rather than compensating downstream.
- Add trimmed, case-normalized, typed, or unit-normalized derivatives alongside raw evidence when those derivatives are needed.
- Treat `vin_like` as an observation, not a guaranteed universal vehicle identifier. Do not rename it to `vin` or assert domain validity without a documented rule.
- Treat request/offer timestamps as separate business, source-update, and ingestion concepts. Do not substitute one for another.
- Retain source record and batch identifiers wherever lineage, replay analysis, or deterministic deduplication may matter.
- Keep synthetic contact fields out of downstream governed outputs by default.

## Modeling boundaries

Use these prefixes when a new layer is justified:

- `stg_`: source-aligned cleanup, explicit types, renamed/normalized derivatives, and preserved provenance;
- `int_`: reusable joins, event ordering, deduplication, lifecycle derivation, or grain changes;
- `dim_` / `fct_`: stable consumer-facing dimensions and facts with explicit contracts.

Do not force the project to have every layer. Create the fewest models that keep grains and responsibilities clear.

Prefer one staging model per seed when staging work begins. Keep valuation-request and offer-event grains separate until a downstream requirement justifies a join. Joining raw grains without first stating cardinality can multiply rows.

## YAML and test style

- Colocate YAML with the model layer.
- Follow the existing repository syntax unless a dbt-version migration is explicitly in scope.
- Describe the model purpose, row grain, provenance, normalization choices, and non-obvious null semantics.
- Test candidate keys only after verifying them against the data.
- Add relationship tests only after measuring orphan behavior and confirming it is expected to be enforced.
- Derive accepted values from observed data plus an established domain contract, never from guesswork.

## Profile and secrets

`profiles.yml.example` defines a `dev` output and reads these environment variables:

- `DBT_SNOWFLAKE_ACCOUNT`
- `DBT_SNOWFLAKE_USER`
- `DBT_ENV_SECRET_SNOWFLAKE_PASSWORD`
- `DBT_SNOWFLAKE_ROLE`
- `DBT_SNOWFLAKE_DATABASE`
- `DBT_SNOWFLAKE_WAREHOUSE`
- `DBT_SNOWFLAKE_SCHEMA` (defaults to `DBT_DEV`)

The example currently uses four threads. The README's sample Snowflake objects are `PLUG_DBT_WH`, `PLUG_DBT_DEV`, and `DBT_DEV`.

Never expose resolved secret values. Authentication requirements can change independently of this repository; if authentication setup is in scope, consult current dbt and Snowflake documentation and propose changes separately rather than silently rewriting the profile contract.
