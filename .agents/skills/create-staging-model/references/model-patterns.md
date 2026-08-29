# Model Patterns

All plug_dbt staging models use incremental append-only loading. Select the SQL shape from the source behavior.

| Source behavior | Structure |
|---|---|
| Semi-structured deliveries with multiple consumers | Incremental shared base extraction plus incremental typed staging models |
| Semi-structured deliveries with one consumer | Direct incremental typed staging model |
| Tabular append-only deliveries | Direct incremental staging model |
| Periodic delivery batches | Incremental model keyed by delivery identifier and batch watermark |
| Local seed with delivery evidence | Incremental seed-backed staging model |
| Mutable current-state relation without delivery history | Blocked; it cannot satisfy the staging delivery contract |

## Files

- Default to `models/staging/stg_<entity>.sql`.
- Create `models/staging/stg_<entity>.yml` with the same base name.
- Create `tests/assert_stg_<entity>__source_completeness.sql`.
- Follow a more specific existing naming pattern when the repository establishes one.

## Shared Base Model

Create a base model only when shared parsing is justified by multiple consumers or expensive nested extraction. A base model under staging must satisfy the same incremental delivery-key and watermark contract.

Preserve:

- raw delivery identifier
- ingestion watermark
- source timestamps
- nested payload or raw evidence needed downstream
- source relation and file provenance

## Standard SQL Shape

1. Configure `materialized = 'incremental'` without `unique_key`.
2. Import explicit source columns.
3. Apply the strict watermark filter inside `{% if is_incremental() %}`.
4. Rename and cast while preserving raw observations.
5. Add normalized derivatives and the delivery surrogate key when required.
6. Emit explicit final columns at the physical-delivery grain.

Use `assets/staging-model.sql` as a scaffold.

## Semi-Structured Deliveries

- Extract the payload object once.
- Cast leaf fields explicitly.
- Preserve the raw payload when it is required evidence.
- Use tolerant conversions only with tests that expose malformed values.
- Do not collapse repeated entities or choose a latest object version.

## Tabular Deliveries

- Preserve source identifiers and raw values.
- Keep delete flags and ingestion metadata.
- Normalize timestamps with explicit Snowflake timestamp variants.
- Do not treat a repeating business key as the delivery key.

## Periodic Batches

- Preserve batch/file provenance.
- Use a delivery identifier that distinguishes records across batches.
- Use the actual ingestion watermark, not merely the reporting period.
- Keep duplicate or repeated deliveries visible.

## Local Seeds

- Reference the seed with `ref('<seed_name>')`.
- Do not repair, deduplicate, or standardize fixture values in the CSV.
- Preserve identifiers, units, timestamps, and provenance.
- Require a deterministic delivery key and ingestion watermark before implementing incremental staging.
