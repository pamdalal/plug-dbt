{{ config(materialized='view') }}

select
    staging.assessed_odometer_kilometers,
    staging.assessed_odometer_miles,
    staging.assessed_odometer_unit,
    staging.assessed_odometer_unit_normalized,
    staging.assessed_odometer_value,
    staging.assessed_odometer_value_numeric,
    staging.assessment_completed_at,
    staging.assessment_completed_at_ts,
    staging.assessment_id,
    staging.assessment_method_version,
    staging.assessment_status,
    staging.assessment_version,
    staging.assessment_version_numeric,
    staging.available_to_model_at,
    staging.available_to_model_at_ts,
    staging.battery_soh_percent,
    staging.battery_soh_unit,
    staging.battery_soh_value,
    staging.condition_grade,
    staging.delivery_sk,
    staging.has_non_z_timestamp_representation,
    staging.ingested_at,
    staging.ingested_at_ts,
    staging.model_year,
    staging.model_year_numeric,
    staging.observed_at,
    staging.observed_at_ts,
    staging.request_id,
    staging.schema_version,
    staging.source_batch_id,
    staging.source_record_id,
    staging.source_system,
    staging.source_updated_at,
    staging.source_updated_at_ts,
    staging.synthetic_vin,
    staging.vehicle_model_family,
    staging.vehicle_segment
from {{ ref('stg_vehicle_assessments') }} as staging
inner join {{ ref('int_vehicle_assessment_dispositions') }} as dispositions
    on staging.delivery_sk = dispositions.delivery_sk
where dispositions.disposition = 'accepted'
