---
name: create-staging-model
description: Create a plug_dbt staging model, paired YAML documentation and tests, and source-to-staging completeness test from one data-source input. Use when the user asks to stage a Snowflake relation or query, an existing dbt source, a dbt seed, or a local seed file in the plug-dbt repository.
---

# Create Staging Model

Apply the repository `AGENTS.md`, then apply `using-plug-dbt-on-snowflake` and `choose-dbt-data-tests`. Treat those project instructions as authoritative when they differ from this skill.

Create all staging artifacts from the source supplied by the user. The source is the only initial input; discover routine implementation details from project metadata, source data, and nearby models.

## Required Outcome

- Create an incremental staging SQL model.
- Create a sibling YAML file with the same base name.
- Document every output column and test every output column with a meaningful invariant.
- Create a reverse source-to-staging completeness test.
- Add source YAML only when an external Snowflake relation is not already declared.
- Preserve existing dbt sources and local seed fixtures unchanged.
- Record inferred grain, delivery key, watermark, and source assumptions.

## Workflow

1. Read `AGENTS.md`, `dbt_project.yml`, the relevant source or seed, and nearby staging pairs.
2. Resolve the input as a dbt source, Snowflake relation/query, seed node, or local seed file.
3. Build the physical-delivery contract in `references/source-discovery.md`.
4. Profile the development source to verify the delivery key, watermark, null behavior, duplicate behavior, and test contracts.
5. Select the source-shape pattern in `references/model-patterns.md`.
6. Propose lineage for the new source-to-staging relationship.
7. Create the SQL/YAML pair, source YAML if required, and completeness test.
8. Validate with `references/testing-and-validation.md`.

Do not ask for source family, model name, folder, column names, or tests when they can be discovered. Ask only when the source lacks a safe physical-delivery key or ingestion watermark, the development target is ambiguous, or a durable column contract cannot be established.

## Accepted Inputs

- `source_name.table_name`
- `database.schema.table`
- a read-only Snowflake query
- a dbt seed name
- a repository-relative CSV seed path

Use dbt project metadata before shell search when the project index is ready. Use read-only Snowflake queries for relation discovery and bounded file reads for local seeds. Never connect to Snowflake through Python.

## Non-Negotiable Staging Contract

- Materialize every staging model as incremental.
- Preserve the raw physical-delivery grain and source evidence.
- Identify or generate a deterministic, non-null delivery key.
- Test the delivery key with `not_null` and `unique`.
- Filter incrementally on a reliable ingestion watermark using a strict greater-than boundary.
- Retain the watermark in the model output.
- Do not configure `unique_key` or a merge strategy.
- Do not deduplicate, reconcile repeated business identifiers, or select canonical records.
- Expose equal-watermark or late-arrival gaps through the reverse completeness test.

If a reliable delivery key or watermark does not exist, stop and report the model as blocked rather than weakening this contract.

## SQL Rules

- Use explicit columns and Snowflake types.
- Structure nontrivial SQL as `source`, `renamed` or `typed`, and `final` CTEs.
- Preserve source identifiers, units, timestamps, and provenance.
- Add normalized derivatives rather than overwriting raw observations.
- Use `dbt_utils.generate_surrogate_key` only when a composite delivery key is required and the package is installed.
- Use `try_to_*` only with a quality assertion that exposes failed conversions.
- Keep synthetic contact fields out of governed outputs unless explicitly required.

Adapt `assets/staging-model.sql`; do not copy unsupported placeholders literally.

## YAML and Tests

- Pair `models/staging/<model>.sql` with `models/staging/<model>.yml`.
- Document purpose, row grain, transformations, incremental boundary, and null semantics.
- List every final-select column alphabetically with a meaningful description.
- Give every output column at least one contract-backed data test.
- Choose tests using the `choose-dbt-data-tests` skill.
- Keep tests nested under their columns.

Adapt `assets/staging-model.yml` and `assets/source-completeness-test.sql`.

## Resources

- `references/source-discovery.md`: Resolve and profile the single source input.
- `references/model-patterns.md`: Select a safe incremental pattern for any source shape.
- `references/testing-and-validation.md`: Complete documentation, tests, and validation.
- `assets/staging-model.sql`: Incremental staging scaffold.
- `assets/staging-model.yml`: Paired documentation and tests scaffold.
- `assets/source.yml`: External Snowflake source declaration scaffold.
- `assets/source-completeness-test.sql`: Reverse completeness test scaffold.
