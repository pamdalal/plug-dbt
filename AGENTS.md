# Agent rules for `plug_dbt`

These rules apply to the entire repository. They are project-specific and take precedence over older or more general guidance in `.agents/skills/` when that guidance conflicts with this file.

## Model SQL and YAML must stay paired

- Every `models/**/*.sql` file must have a sibling YAML file with the same base name. For example, `models/staging/stg_offers.sql` must be paired with `models/staging/stg_offers.yml`.
- Do not place multiple model definitions in a shared layer-level YAML file. Each model YAML file must contain the definition for its matching SQL model only.
- Create, update, rename, move, and delete the SQL/YAML pair together.
- Use `version: 2`, and make the model `name` match the SQL filename exactly.
- Document the model's purpose, row grain, important transformations, incremental boundary, and non-obvious null semantics.
- List every column emitted by the model's final `select`; do not leave undocumented output columns or retain stale YAML entries.
- Give every column a meaningful `description` that explains its semantics rather than restating its name.
- Order column entries alphabetically by column name in the YAML file. Tests remain nested under their column.

## Determine column tests from observed data

Before choosing tests, profile the model's inputs or output in the development target. For every output column, check at least:

- null count and null rate;
- distinct count and duplicate count where uniqueness could be meaningful;
- minimum, maximum, and relevant outliers for numeric, date, and timestamp columns;
- distinct values and frequencies for categorical columns.

Then add applicable column tests to the model's YAML file:

- Add `not_null` only when nulls violate the model contract.
- Add `unique` only when the column is a logical key at the declared grain and the scan finds no duplicates. Observed uniqueness alone does not establish a durable key.
- Add `accepted_values` only for a stable, enumerable domain supported by both the observed values and an established business or source contract. Do not turn incidental sample values into a permanent contract.
- Add range tests only when a defensible lower or upper bound exists. State the bound and whether it is inclusive. Use a project-supported generic range test; if none exists, add a project-local generic test or ask before introducing a package dependency.
- Keep tests high-signal. Every column must be documented and profiled, but do not invent a test for a column that has no stable invariant.

Use bounded, cost-conscious dbt queries against a confirmed development target. If the data cannot be scanned because credentials, the warehouse, or an upstream relation is unavailable, report the profiling and test selection as blocked; do not guess and do not claim the model is complete.

## Staging models must implement incremental loading

- Every `models/staging/*.sql` model must use dbt incremental materialization and include an `{% if is_incremental() %}` branch that limits source processing.
- An incremental branch in a model still configured as a view is not sufficient. Add a model-level incremental configuration or update the applicable project configuration as part of the model change.
- Base the incremental boundary on a reliable source update or ingestion field. Document the chosen watermark in the paired YAML file.
- Preserve the declared grain across both full-refresh and incremental paths. Handle equal watermarks, repeated deliveries, updates, and late-arriving records explicitly so reruns are idempotent.
- Configure a `unique_key` and incremental strategy when the model's grain supports updates or replay. Do not invent a key, ordering rule, or deduplication policy from filenames or a small sample.
- If no reliable watermark or replay-safe strategy exists, stop and ask for the intended ingestion semantics rather than adding unsafe incremental logic.
- Never run `--full-refresh` without explicit user approval.

## Definition of done for model changes

A model change is not complete until its SQL/YAML pair follows these rules, the profiling evidence has informed its tests, and the smallest relevant `dbt parse` and scoped model build checks have been run or reported as blocked with the exact reason.
