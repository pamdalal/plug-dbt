{{ config(materialized='view') }}

select
    staging.delivery_sk,
    staging.has_non_z_timestamp_representation,
    staging.ingested_at,
    staging.ingested_at_ts,
    staging.market_region,
    staging.odometer_kilometers,
    staging.odometer_miles,
    staging.odometer_unit,
    staging.odometer_unit_normalized,
    staging.odometer_value,
    staging.odometer_value_numeric,
    staging.request_id,
    staging.schema_version,
    staging.seller_id,
    staging.source_batch_id,
    staging.source_record_id,
    staging.source_system,
    staging.source_updated_at,
    staging.source_updated_at_ts,
    staging.submission_channel,
    staging.submitted_at,
    staging.submitted_at_ts,
    staging.synthetic_vin
from {{ ref('stg_valuation_requests') }} as staging
inner join {{ ref('int_valuation_request_dispositions') }} as dispositions
    on staging.delivery_sk = dispositions.delivery_sk
where dispositions.disposition = 'accepted'
