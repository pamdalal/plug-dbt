---
name: choose-dbt-data-tests
description: >-
  Select and implement dbt data tests for models by prioritizing native dbt
  generic tests in the model's paired YAML, then dbt-utils generic tests in
  that YAML, then singular SQL data tests under tests/. Use when adding,
  reviewing, or refactoring data-quality tests for models, including
  nullability, uniqueness, accepted values, relationships, ranges, recency,
  completeness, row comparisons, and cross-column or multi-row invariants.
---

# Choose dbt data tests

Apply the repository `AGENTS.md` and the `using-plug-dbt-on-snowflake` skill first. Use this skill for data tests, not dbt unit tests.

## Establish the assertion

1. Read the model SQL, its same-named YAML file, its upstream inputs, and relevant downstream contracts.
2. Inventory every column emitted by the model's final `select`.
3. For every output column, state at least one meaningful invariant and the rows that should make it fail.
4. Profile every output column in the confirmed development target as required by `AGENTS.md`.
5. Require both observed evidence and a durable source or business contract. Do not convert an accidental property of the current sample into a test.
6. Add at least one meaningful, contract-backed data test for every output column to the paired YAML file. If no stable invariant can be established, report the model as blocked rather than omitting the test or inventing one.
7. Choose exactly one implementation for each assertion using the ranking below. Do not duplicate the same assertion at multiple ranks.

## Rank 1: use native dbt generic tests in model YAML

Try all four built-in tests before considering a package or SQL file:

- Use `not_null` for contractually required values.
- Use `unique` for a single-column key or a deliberately emitted surrogate key at the declared grain.
- Use `accepted_values` for a stable enumerable domain.
- Use `relationships` for referential integrity to another dbt resource, including referencing-row conditions expressible with the test's `config.where`.

Keep the test in the model's paired YAML file. Prefer a clear native test over a dbt-utils equivalent or a hand-written query. Do not force composite uniqueness into unsafe string concatenation; use rank 2 when no collision-safe model key exists.

## Rank 2: use dbt-utils generic tests in model YAML

Use dbt-utils only when no native test expresses the invariant clearly and a cataloged dbt-utils test does. Read [references/dbt-utils-generic-tests.md](references/dbt-utils-generic-tests.md) when evaluating this rank.

Before referencing `dbt_utils`:

1. Check `dependencies.yml` or `packages.yml` and `package-lock.yml` for the installed package and version.
2. Confirm that the installed version contains the selected test and supports the active dbt version and Snowflake adapter.
3. If the dependency is absent, explain which test requires it and ask for approval before adding the package or running `dbt deps`. Do not silently introduce a dependency.

Attach column-scoped and model-scoped dbt-utils tests to the same-named model YAML file. Prefer the narrowest named test, such as `accepted_range`, `unique_combination_of_columns`, or `relationships_where`, instead of treating `expression_is_true` as a universal fallback.

Follow the repository's existing `tests:` versus `data_tests:` convention unless a syntax migration is in scope. dbt Core 1.10.5+ accepts generic-test inputs under `arguments:`; dbt-utils recommends that form for dbt Core 1.10.6+, and Fusion requires it. For older versions, follow the installed version's supported syntax. Keep execution settings such as `where`, `severity`, and `store_failures` under `config:`.

## Rank 3: use a singular SQL data test under `tests/`

Create a singular SQL test only when neither rank 1 nor rank 2 can express the invariant without obscuring it. Typical cases include asymmetric source-to-model completeness, model-specific multi-row business rules, or a one-off comparison that needs custom failure columns.

For each singular test:

- Create one descriptively named file under `tests/`, such as `assert_stg_offers__source_completeness.sql`.
- Implement one `select` statement that returns the failing rows and returns zero rows on success.
- Use `ref()` or `source()` rather than hard-coded relation names.
- Select useful identifiers and diagnostic values so failures are actionable.
- Omit the trailing semicolon.
- Do not list the singular test in model YAML; dbt discovers it from `test-paths`.
- Avoid duplicating a reusable generic pattern across several SQL files. If repetition emerges, stop and propose a reusable generic test separately.

Do not replace a clear YAML generic test with singular SQL merely to avoid checking or installing an approved dependency. Singular tests may supplement model coverage, but they do not satisfy the required paired-YAML test coverage for any output column.

## Common choices

| Invariant | Preferred implementation |
| --- | --- |
| Required column | Native `not_null` |
| Single-column or emitted surrogate key | Native `unique` plus `not_null` |
| Stable finite domain | Native `accepted_values` |
| Foreign key, optionally filtered on referencing rows with `config.where` | Native `relationships` |
| Numeric, date, or timestamp bounds | `dbt_utils.accepted_range` |
| Composite key without an emitted surrogate | `dbt_utils.unique_combination_of_columns` |
| Foreign key requiring separate referencing- and referenced-side conditions | `dbt_utils.relationships_where` |
| Cross-column arithmetic invariant | `dbt_utils.expression_is_true` |
| Freshness or sequence invariant | `dbt_utils.recency` or `dbt_utils.sequential_values` |
| Exact relation comparison | `dbt_utils.equality` |
| Reverse source-to-staging completeness | Singular SQL returning missing source deliveries |
| One-off model-specific multi-row rule | Singular SQL returning violating rows |

## Validate the choice

1. Reconcile the final-select column inventory against the paired YAML and confirm that every output column has at least one meaningful, contract-backed data test.
2. Run `dbt parse` after YAML, package, or Jinja changes.
3. Run the smallest scoped `dbt test` or `dbt build` selector that executes the changed model and test.
4. Inspect compiled SQL and failure rows when a test fails.
5. Report missing column contracts, package installation, warehouse execution, or profiling as blocked when prerequisites are unavailable; do not claim the model or unrun tests passed.
