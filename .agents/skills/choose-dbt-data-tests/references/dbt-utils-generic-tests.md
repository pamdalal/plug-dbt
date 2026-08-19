# dbt-utils generic data-test catalog

This reference summarizes the official `dbt-labs/dbt-utils` repository reviewed on 2026-08-18. Treat the version installed by the project as authoritative because the catalog and syntax can change.

Primary sources:

- [dbt-utils repository and generic-test documentation](https://github.com/dbt-labs/dbt-utils)
- [dbt-utils generic test implementations](https://github.com/dbt-labs/dbt-utils/tree/main/macros/generic_tests)
- [dbt data-test documentation](https://docs.getdbt.com/docs/build/data-tests)
- [dbt data-tests YAML property](https://docs.getdbt.com/reference/resource-properties/data-tests)

## Catalog

| Test | Scope | Use for |
| --- | --- | --- |
| `accepted_range` | Column | Minimum or maximum bounds, inclusive or exclusive; bounds may be scalars or comparable columns. |
| `at_least_one` | Column | Requiring at least one non-null value without requiring every row to be non-null. |
| `cardinality_equality` | Column | Matching distinct-value cardinality with a column in another relation. |
| `equal_rowcount` | Model | Requiring the same row count as another relation. |
| `equality` | Model | Comparing two relations, optionally by selected/excluded columns and numeric precision. |
| `expression_is_true` | Model or column | Evaluating an invariant expressed as a SQL predicate when no narrower named test fits. |
| `fewer_rows_than` | Model | Requiring fewer rows than another relation. |
| `mutually_exclusive_ranges` | Model | Preventing overlaps between lower/upper ranges, optionally within partitions and with gap rules. |
| `not_accepted_values` | Column | Rejecting a small stable list of forbidden values. |
| `not_constant` | Column | Requiring more than one observed value. |
| `not_empty_string` | Column | Rejecting empty or, by default, whitespace-only strings. |
| `not_null_proportion` | Column | Enforcing an allowed proportion of non-null values instead of absolute `not_null`. |
| `recency` | Model | Requiring a timestamp field to contain sufficiently recent data. |
| `relationships_where` | Column | Referential integrity with explicit filters on the referencing or referenced relation. |
| `sequential_values` | Column | Requiring numeric or timestamp values to follow a defined interval. |
| `unique_combination_of_columns` | Model | Enforcing composite uniqueness without concatenating columns. |

## Selection cautions

- Prefer native `not_null`, `unique`, `accepted_values`, and `relationships` whenever they express the same invariant.
- Prefer a native `unique` test on a model-emitted surrogate key over composite testing when that key is already part of the model contract.
- Use `expression_is_true` only after checking for a more specific test; broad expressions can hide intent and scan substantial data.
- Do not use `equal_rowcount` as proof of row-level completeness or equality. Equal counts can still contain different records.
- Do not use `cardinality_equality` as proof that the value sets are equal; matching cardinalities can contain different values.
- Set `accepted_range` bounds from a durable contract, not observed minima or maxima alone.
- Prefer native `relationships` with `config.where` when only the referencing rows need filtering. Use `relationships_where` when the contract requires separate referencing- and referenced-side conditions.
- Use relationship filters only when the exclusion is a real contract. Do not filter known failures merely to obtain a pass.
- Confirm null behavior for every test. Pair key or range tests with native `not_null` when nulls independently violate the contract.

## Grouped execution

The reviewed upstream README supports `group_by_columns` for:

- `equal_rowcount`
- `fewer_rows_than`
- `recency`
- `at_least_one`
- `not_constant`
- `sequential_values`
- `not_null_proportion`

Use grouping only when the invariant is genuinely defined per group, not solely to reduce scan size.

## YAML syntax

dbt Core 1.10.5+ accepts test inputs under `arguments:`. The reviewed dbt-utils README recommends that form for dbt Core 1.10.6+, and Fusion requires it. Older dbt Core versions may require arguments directly beneath the test name. Inspect the active dbt version and preserve the repository's supported syntax rather than copying an upstream example blindly.
