# Source Discovery

Build a physical-delivery contract from the single source input before writing files.

## Resolve the Input

### Existing dbt source

1. Find the source node and source YAML.
2. Read immediate staging children and their paired YAML files.
3. Reuse the existing `source()` expression.

### Snowflake relation

1. Search for a matching declared source.
2. Confirm the resolved profile targets the approved development database and schema.
3. If undeclared, inspect `information_schema.columns` with a read-only query.
4. Profile candidate keys, ingestion timestamps, nulls, duplicates, ranges, and stable categories with bounded queries.
5. Add source YAML following the current repository convention.

### Snowflake query

1. Confirm the statement is read-only.
2. Identify the underlying relations and projected delivery grain.
3. Prefer declared sources for underlying external relations.
4. Keep the query as an import boundary only when it intentionally defines the source deliveries.

### dbt seed or local seed file

1. Resolve the seed node or repository-relative CSV.
2. Read the header and a small representative sample.
3. Inspect the seed's loaded Snowflake types in the development target.
4. Reference it with `ref()` and do not edit the fixture.
5. Verify a physical-delivery key and ingestion watermark from the seed contract.

## Required Contract

Capture:

- source expression
- source entity and staging model name
- explicit columns and Snowflake types
- physical-delivery grain
- existing or composite delivery key
- reliable ingestion watermark
- append and late-arrival behavior
- repeated-delivery behavior
- delete or tombstone fields
- units and timestamp semantics
- sensitive or synthetic fields
- nested payload paths
- transformations needed for normalized derivatives

## Verify the Delivery Key

Use this evidence order:

1. Documented physical-delivery identifier
2. Existing source constraint or established test
3. Composite fields whose uniqueness is verified in development data

Observed uniqueness alone does not establish durability. The fields must explain why two distinct physical deliveries cannot share the key.

If no single key exists, generate a surrogate key from verified physical-delivery fields. Do not use a business identifier that repeats across deliveries.

## Verify the Watermark

Prefer an ingestion or load timestamp that:

- is present on every delivery
- does not change after ingestion
- orders newly appended deliveries
- is retained in staging

Use a strict `>` incremental boundary against the maximum staged watermark.

Do not substitute a business event time or mutable `updated_at` unless it is explicitly the source ingestion contract.

## Blocked Conditions

Stop and report the exact blocker when:

- no deterministic physical-delivery key exists
- no reliable ingestion watermark exists
- the development target cannot be confirmed
- source data cannot be profiled
- a column cannot receive a durable meaningful test

Do not fall back to a view, table, merge, deduplication, or guessed assertion.
