# Four-seed candidate scaffold migration

## Status

**Repository migration implemented on August 28, 2026.**

The four canonical CSVs were transferred byte-for-byte from clean
`plug-tech-screen` commit
`24fc26b1539754f15c18e9f8fc43f200f55ecc49`. Preflight results:

- `uvx --python 3.12 hatch run check`: 100 tests passed;
- `uvx --python 3.12 hatch run test-cov`: 100 tests passed at 92% coverage;
- deterministic `hatch run generate`: clean source diff;
- byte comparison: passed for all four CSVs; and
- `scripts/validate_seed_handoff.py`: passed envelope checks and profiles.

The repository graph is migrated. Snowflake loading, warehouse profiling, and
scoped builds remain environment validation steps and must run only in a
pre-created isolated non-production schema.

## Seed boundary

| Seed | Rows | Columns | Fixed source system |
| --- | ---: | ---: | --- |
| `raw_valuation_requests` | 2,000 | 14 | `valuation_portal` |
| `raw_vehicle_assessments` | 1,916 | 23 | `vehicle_assessment` |
| `raw_offer_events` | 3,391 | 28 | `offer_service` |
| `raw_marketplace_events` | 2,951 | 23 | `dealer_marketplace` |

Every seed column is explicitly configured as Snowflake `VARCHAR`, with
`quote_columns: false`. The boundary does not repair, deduplicate, reorder, or
infer analytical types.

## Physical staging

The four paired staging models are:

- `stg_valuation_requests`
- `stg_vehicle_assessments`
- `stg_offer_events`
- `stg_marketplace_events`

Each model preserves every raw field and adds a namespaced `delivery_sk`,
parsed `TIMESTAMP_TZ` values, fixed-point numeric derivatives, explicit
odometer or amount normalization, and representation flags. All four use
incremental append materialization with no `unique_key` or merge behavior.

The incremental boundary is parsed `ingested_at` strictly greater than the
target maximum. A null target maximum loads all rows. `on_schema_change='fail'`
prevents prototype and canonical schemas from mixing.

## Runtime dispositions

The source-specific views are:

- `int_valuation_request_dispositions`
- `int_vehicle_assessment_dispositions`
- `int_offer_event_dispositions`
- `int_marketplace_event_dispositions`

Replay groups follow the frozen source contract:

| Source | Replay group |
| --- | --- |
| Valuation requests | `request_id` |
| Vehicle assessments | `(assessment_id, assessment_version)` |
| Offer events | `(offer_id, event_sequence)` |
| Marketplace events | `(auction_id, event_sequence)` |

Timestamps compare by parsed instant; other payload fields compare by delivered
text with null position preserved. Survivors use earliest parsed `ingested_at`,
then `source_record_id`. Conflicting immutable-key payloads are quarantined.

The semantic checks cover supported schema/row matrices, request and VIN
relationships, point-in-time pricing-assessment availability, marketplace
offer relationships, and sale confirmation after one matching awarded close.

`int_delivery_dispositions` exposes:

- `source`
- `delivery_sk`
- `request_id`
- `disposition`
- `disposition_reason`
- `survivor_delivery_sk`

The four `int_canonical_*` views contain accepted replay survivors only.
Warning and normalization flags remain separate from disposition.

## Reconciliation

The test suite includes:

- source-to-staging composite-key completeness for all four sources;
- staging-to-source composite-key completeness for all four sources;
- one disposition per physical delivery;
- `physical = accepted + duplicate + quarantined` by source;
- disposition reason and survivor-pointer contracts; and
- exact accepted-disposition-to-canonical-input equality.

All results derive at dbt runtime. No finding IDs, target rows, expected
survivor maps, disposition totals, latent values, or lifecycle answers are
stored in this repository.

## Retired prototype

The migration removes `stg_example`, `fct_events`, the prototype replay test,
and all six prototype analyses. No compatibility layer is retained under the
approved assumption that no external consumer requires `fct_events`.

## Candidate handoff

`fct_vehicle_lifecycle` remains intentionally unimplemented. Its future paired
SQL/YAML model has one row per `request_id` and this 13-column contract:

1. `request_id`
2. `selected_assessment_id`
3. `selected_assessment_version`
4. `offer_id`
5. `offer_version`
6. `pricing_evaluation_id`
7. `auction_id`
8. `winning_bid_id`
9. `buyer_dealer_id`
10. `transaction_id`
11. `pricing_label_status`
12. `terminal_stage`
13. `dropoff_reason`

The candidate owns point-in-time assessment selection, current offer-version
selection, marketplace reconstruction, request-grain fan-in, lifecycle and
pricing-label classification, focused tests, reconciliation, and bounded
metrics.

## Warehouse validation order

Use a pre-created non-production schema supplied through
`DBT_SNOWFLAKE_SCHEMA`; the profile fallback is `DBT_MIGRATION`.

1. Confirm required variables without printing values.
2. Run `dbt parse` and scoped `dbt ls`.
3. Run `dbt debug` and confirm the isolated target.
4. Seed exactly the four source relations.
5. Profile every loaded seed and staging column.
6. Build staging, dispositions, common reconciliation, and canonical inputs in
   that order with scoped selectors.

Do not run an unscoped build, production command, direct Snowflake DDL, or
`--full-refresh`.
