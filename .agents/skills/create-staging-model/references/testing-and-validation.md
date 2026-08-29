# Testing and Validation

Apply `choose-dbt-data-tests` for detailed test selection.

## Profile Before Testing

For every output column, inspect:

- null count and null rate
- distinct count and duplicates when uniqueness may matter
- minimum, maximum, and relevant outliers
- distinct values and frequencies for categories
- conversion failures for normalized derivatives

Use bounded, cost-conscious queries against a confirmed development target.

## Paired YAML

- Match the SQL filename exactly.
- Document model purpose, physical-delivery grain, key, incremental boundary, transformations, and null semantics.
- List every output column alphabetically.
- Give every column a meaningful description.
- Add at least one durable, meaningful test to every output column.
- Test the delivery key with `not_null` and `unique`.
- Test every surrogate-key component.
- Do not promote incidental sample properties into permanent contracts.

If any output column lacks a defensible test, report the model as blocked.

## Reverse Completeness

Create `tests/assert_<model_name>__source_completeness.sql`.

The singular test must:

- reconstruct the source delivery key using the same fields as staging
- return source deliveries absent from the staging model
- use `source()` or `ref()`
- expose identifiers and watermark values for diagnosis
- return zero rows when complete

Use `assets/source-completeness-test.sql` as a scaffold.

## Validation

1. Confirm the SQL/YAML pair and final-select inventory match.
2. Confirm source and ref names resolve.
3. Run `dbt parse`.
4. Compile the narrow staging model.
5. Preview the delivery key, watermark, and representative columns with a bounded query.
6. Follow the host Wizard validation gate for the scoped build and tests.

Do not run `dbt run`, `dbt build`, or `dbt test` during development outside the validation gate.

If credentials or warehouse access are unavailable, report profiling and data-test selection as blocked. Do not guess or claim completion.
