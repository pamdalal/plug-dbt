{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='fail'
    )
}}

with source as (

    select
        assessed_odometer_unit,
        assessed_odometer_value,
        assessment_completed_at,
        assessment_id,
        assessment_method_version,
        assessment_status,
        assessment_version,
        available_to_model_at,
        battery_soh_unit,
        battery_soh_value,
        condition_grade,
        ingested_at,
        model_year,
        observed_at,
        request_id,
        schema_version,
        source_batch_id,
        source_record_id,
        source_system,
        source_updated_at,
        synthetic_vin,
        vehicle_model_family,
        vehicle_segment,
        try_to_decimal(assessed_odometer_value, 38, 0)
            as assessed_odometer_value_numeric,
        try_to_timestamp_tz(assessment_completed_at) as assessment_completed_at_ts,
        try_to_decimal(assessment_version, 38, 0) as assessment_version_numeric,
        try_to_timestamp_tz(available_to_model_at) as available_to_model_at_ts,
        try_to_decimal(battery_soh_value, 38, 1) as battery_soh_percent,
        to_timestamp_tz(ingested_at) as ingested_at_ts,
        try_to_decimal(model_year, 4, 0) as model_year_numeric,
        try_to_timestamp_tz(observed_at) as observed_at_ts,
        try_to_timestamp_tz(source_updated_at) as source_updated_at_ts
    from {{ ref('raw_vehicle_assessments') }}

    {% if is_incremental() %}
        where (
            (select max(ingested_at_ts) from {{ this }}) is null
            or to_timestamp_tz(ingested_at)
                > (select max(ingested_at_ts) from {{ this }})
        )
    {% endif %}

)

select
    assessed_odometer_unit,
    assessed_odometer_value,
    assessed_odometer_value_numeric,
    assessment_completed_at,
    assessment_completed_at_ts,
    assessment_id,
    assessment_method_version,
    assessment_status,
    assessment_version,
    assessment_version_numeric,
    available_to_model_at,
    available_to_model_at_ts,
    battery_soh_percent,
    battery_soh_unit,
    battery_soh_value,
    condition_grade,
    ingested_at,
    ingested_at_ts,
    model_year,
    model_year_numeric,
    observed_at,
    observed_at_ts,
    request_id,
    schema_version,
    source_batch_id,
    source_record_id,
    source_system,
    source_updated_at,
    source_updated_at_ts,
    synthetic_vin,
    vehicle_model_family,
    vehicle_segment,
    cast(
        case
            when assessed_odometer_unit = 'km' then assessed_odometer_value_numeric
            when assessed_odometer_unit = 'mi'
                then assessed_odometer_value_numeric * 1.609344
        end
        as number(38, 6)
    ) as assessed_odometer_kilometers,
    cast(
        case
            when assessed_odometer_unit = 'mi' then assessed_odometer_value_numeric
            when assessed_odometer_unit = 'km'
                then assessed_odometer_value_numeric / 1.609344
        end
        as number(38, 6)
    ) as assessed_odometer_miles,
    assessed_odometer_unit = 'km' as assessed_odometer_unit_normalized,
    md5(
        to_json(
            array_construct(
                'raw_vehicle_assessments',
                source_system,
                source_record_id
            )
        )
    ) as delivery_sk,
    (
        coalesce(not regexp_like(assessment_completed_at, 'Z$'), false)
        or coalesce(not regexp_like(available_to_model_at, 'Z$'), false)
        or not regexp_like(ingested_at, 'Z$')
        or coalesce(not regexp_like(observed_at, 'Z$'), false)
        or not regexp_like(source_updated_at, 'Z$')
    ) as has_non_z_timestamp_representation
from source
