# Snowflake dbt workflow

Use this workflow for warehouse-connected development, Snowflake SQL, profiling, validation, impact analysis, and error diagnosis.

## 1. Confirm local and target context

Read the project/profile files first. Disable shell tracing and check required variable presence without expanding values into command arguments:

```sh
set +x
missing=0
for name in \
  DBT_SNOWFLAKE_ACCOUNT \
  DBT_SNOWFLAKE_USER \
  DBT_ENV_SECRET_SNOWFLAKE_PASSWORD \
  DBT_SNOWFLAKE_ROLE \
  DBT_SNOWFLAKE_DATABASE \
  DBT_SNOWFLAKE_WAREHOUSE
do
  if ! printenv "$name" | grep -q .; then
    printf 'missing: %s\n' "$name"
    missing=1
  fi
done
test "$missing" -eq 0
```

`DBT_SNOWFLAKE_SCHEMA` is optional in the checked-in example because it defaults to `DBT_DEV`. Do not use `env`, `set`, `cat .env`, command substitution around secret values, or an equivalent command that prints secrets.

Before `dbt debug`, establish an expected non-production database/schema/role/warehouse allowlist from the checked-in sample or explicit user confirmation. Compare the non-secret target variables with tracing disabled and stop on a mismatch. Do not use `dbt debug` to discover the target: it opens a Snowflake connection. After the preflight passes, run it to validate the intended `dev` output and stop if the resolved target is unexpected.

Do not change authentication opportunistically. If setup or authentication is the task, consult the current [dbt Snowflake setup documentation](https://docs.getdbt.com/docs/local/connect-data-platform/snowflake-setup) and Snowflake authentication guidance before proposing a profile update.

## 2. Start with cheap project checks

Use commands that avoid model execution before consuming warehouse compute:

```sh
dbt parse
dbt ls --select "resource_type:seed" --output name
dbt ls --select "resource_type:model" --output name
dbt ls --select "model_name+" --output name
```

Quote selectors so the shell cannot reinterpret graph syntax. Review the selected names before running `dbt build`.

## 3. Discover the data with bounded queries

Use `dbt show` so Jinja and `ref()` resolve through the project. First determine whether the required seed relations exist in the development schema. On a fresh schema, load only the inputs needed for the task:

```sh
dbt seed --select "raw_valuation_requests raw_offer_events"
```

Narrow that selector to one seed when only one lineage is involved. Seeding writes development relations and consumes warehouse resources, so do it only after the target preflight.

Then inspect the inputs or model:

```sh
dbt show --inline "select * from {{ ref('raw_valuation_requests') }}" --limit 20
dbt show --inline "select * from {{ ref('raw_offer_events') }}" --limit 20
dbt show --select "model_name" --limit 20
```

`dbt show` compiles and runs the selected model or inline query against Snowflake. Its `--limit` changes the executed SQL, not only terminal display. Keep inline SQL read-only; dbt cannot guarantee that arbitrary inline SQL is non-mutating. See the current [dbt show reference](https://docs.getdbt.com/reference/commands/show).

For every input used by a model, inspect the loaded Snowflake column types as well as values. CSV quoting does not guarantee string types after `dbt seed`; use a bounded metadata or `typeof(...)` query through `dbt show` when type preservation matters. Establish:

- loaded column types, row count, and stated grain;
- duplicate and null counts for candidate keys;
- distinct lifecycle/unit/enumeration values;
- timestamp parse failure counts and min/max values;
- relationship/orphan counts for intended joins;
- rows that would be dropped or multiplied by filtering, deduplication, or joins.

Use early filters or bounded samples for exploratory row inspection. Run full-table aggregate checks only for assumptions that must hold across the complete input.

## 4. Make Snowflake semantics explicit

### Identifiers

Use unquoted snake_case identifiers. Snowflake stores and resolves unquoted identifiers as uppercase; quoted identifiers preserve case and require exact future quoting. Do not introduce quoted mixed-case identifiers unless the project intentionally adopts that contract. See [Snowflake identifier requirements](https://docs.snowflake.com/en/sql-reference/identifiers-syntax).

### Timestamps

Choose a timestamp variant deliberately:

- Use `timestamp_tz` when the source offset is meaningful and the value represents an absolute instant.
- Use `timestamp_ntz` only for a documented wall-clock value with no time-zone semantics.
- Avoid bare `timestamp`; Snowflake maps it according to `TIMESTAMP_TYPE_MAPPING` and defaults it to `timestamp_ntz`.
- Convert to a canonical timezone only in a new derivative column, preserving the source timestamp text or typed source-offset value.

The fixture timestamps use ISO-like strings with `Z`; verify parsing with bounded queries and expose failures. Prefer explicit functions such as `try_to_timestamp_tz` only when a test or profiling query detects the resulting nulls. See [Snowflake date and time types](https://docs.snowflake.com/en/sql-reference/data-types-datetime).

### Numeric values and units

- Use fixed-point `number(precision, scale)` or `decimal`, not `float`, for currency.
- Preserve `offer_amount` and `offer_amount_unit` before adding a canonical amount.
- Establish the canonical unit and rounding rule before normalization.
- Reject, quarantine, or visibly flag unknown units according to an explicit business decision; do not silently treat them as the default.
- Preserve `currency_code`; unit normalization does not perform currency conversion.
- Apply the same preservation-first rule to odometer values and units.

### Strings and identifiers

- Preserve source text before adding `trim`, `upper`, or lower-case derivatives.
- Do not treat an empty string, whitespace, and null as equivalent without profiling and documenting the rule.
- Keep leading-zero-sensitive fields such as postal codes as strings unless a business contract says otherwise.

### Event ordering and deduplication

- State whether the target grain is physical delivery, source event, offer version, offer, request, or another entity.
- Use a deterministic order with documented tie-breakers before `row_number()` or similar logic.
- Measure duplicate identities and exact duplicate payloads separately.
- Keep source delivery/batch/ingestion fields through any model that selects one record from several.
- Do not assume ingestion order equals business event order.

## 5. Validate the output contract

Ensure required parents exist before previewing. For a fresh development schema, seed the required fixtures or deliberately build only the model's ancestors:

```sh
dbt build --select "+model_name" --exclude "model_name"
```

Inspect the selector expansion with `dbt ls` first. Then preview the model:

```sh
dbt show --select "model_name" --limit 20
```

Then run focused profiling through `--inline` queries using `ref('model_name')`. Confirm the declared grain, key, unit/timestamp semantics, row preservation, and join cardinality.

Build the smallest affected selection:

```sh
dbt build --select "model_name"
```

If an unbuilt parent is required in the development schema, inspect the graph and deliberately include it:

```sh
dbt build --select "+model_name"
```

Use `model_name+1` or another bounded descendant depth only when downstream impact must be tested. Do not default to an unscoped `dbt build` or `dbt test`.

## 6. Diagnose failures from evidence

Start with the console error, then inspect:

1. `target/run_results.json` and its `metadata.generated_at`;
2. the failing resource status and message;
3. `target/compiled/` for rendered select SQL;
4. `target/run/` for rendered materialization SQL;
5. the tail of `logs/dbt.log` for the most recent invocation.

Classify before editing:

- parse/configuration error: YAML, Jinja, duplicate resources, or project configuration;
- compilation/SQL error: invalid rendered Snowflake SQL or an unsupported function/type;
- data-test failure: evidence violates a declared expectation;
- connection/permission error: profile, role, database, schema, warehouse, network, or authentication;
- logic error: command succeeds but grain, values, or cardinality are wrong.

Fix the root cause and rerun the narrowest validating command. Never remove a test, discard malformed records, broaden privileges, or change the target merely to obtain a passing command.

## 7. Manage Snowflake cost and safety

- Use the repository's development database, schema, role, and warehouse only.
- Rely on the configured small auto-suspending warehouse; do not resize or alter it from this skill.
- Prefer `view` for staging under the current project default.
- Use selectors for every build/test/run command.
- Bound previews and inspect selector expansion before execution.
- Ask before tables, incrementals, full refreshes, clones, clustering keys, or broad backfills because they change compute/storage behavior.
- Report commands that were planned but not executed, along with the missing credential, target, permission, or network prerequisite.
