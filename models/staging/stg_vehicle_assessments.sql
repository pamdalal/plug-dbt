{{ config(
    materialized = 'incremental',
    incremental_strategy = 'append'
) }}

with source as (

    select
        source_record_id
        , source_system
        , source_batch_id
        , schema_version
        , synthetic_vin
        , request_id
        , source_updated_at
        , ingested_at
        , assessment_id
        , assessment_version
        , assessment_status
        , assessment_method_version
        , vehicle_model_family
        , vehicle_segment
        , model_year
        , assessed_odometer_value
        , assessed_odometer_unit
        , battery_soh_value
        , battery_soh_unit
        , condition_grade
        , observed_at
        , assessment_completed_at
        , available_to_model_at
    from
        {{ ref('raw_vehicle_assessments') }}

    {% if is_incremental() %}
    where
        cast(ingested_at as timestamp_ntz) > (
            select
                coalesce(
                    max(ingested_at_ts)
                    , '1900-01-01'::timestamp_ntz
                )
            from
                {{ this }}
        )
    {% endif %}

)

, typed as (

    select
        source_record_id
        , source_system
        , source_batch_id
        , schema_version
        , cast(schema_version as number(10, 2)) as schema_version_num
        , synthetic_vin
        , request_id
        , source_updated_at
        , cast(source_updated_at as timestamp_ntz) as source_updated_at_ts
        , ingested_at
        , cast(ingested_at as timestamp_ntz) as ingested_at_ts
        , assessment_id
        , assessment_version
        , cast(assessment_version as number(10, 0)) as assessment_version_num
        , assessment_status
        , assessment_method_version
        , vehicle_model_family
        , vehicle_segment
        , model_year
        , cast(model_year as number(4, 0)) as model_year_num
        , assessed_odometer_value
        , cast(assessed_odometer_value as number(18, 2)) as assessed_odometer_value_num
        , assessed_odometer_unit
        , case
            when assessed_odometer_unit = 'mi'
                then cast(assessed_odometer_value as number(18, 3))
            when assessed_odometer_unit = 'km'
                then cast(assessed_odometer_value / 1.609344 as number(18, 3))
        end as assessed_odometer_miles
        , case
            when assessed_odometer_unit = 'km'
                then cast(assessed_odometer_value as number(18, 3))
            when assessed_odometer_unit = 'mi'
                then cast(assessed_odometer_value * 1.609344 as number(18, 3))
        end as assessed_odometer_kilometers
        , battery_soh_value
        , cast(battery_soh_value as number(5, 2)) as battery_soh_percent
        , battery_soh_unit
        , condition_grade
        , observed_at
        , cast(observed_at as timestamp_ntz) as observed_at_ts
        , assessment_completed_at
        , cast(assessment_completed_at as timestamp_ntz) as assessment_completed_at_ts
        , available_to_model_at
        , cast(available_to_model_at as timestamp_ntz) as available_to_model_at_ts
    from
        source

)

, final as (

    select
        source_record_id
        , source_system
        , source_batch_id
        , schema_version
        , schema_version_num
        , synthetic_vin
        , request_id
        , source_updated_at
        , source_updated_at_ts
        , ingested_at
        , ingested_at_ts
        , assessment_id
        , assessment_version
        , assessment_version_num
        , assessment_status
        , assessment_method_version
        , vehicle_model_family
        , vehicle_segment
        , model_year
        , model_year_num
        , assessed_odometer_value
        , assessed_odometer_value_num
        , assessed_odometer_unit
        , assessed_odometer_miles
        , assessed_odometer_kilometers
        , battery_soh_value
        , battery_soh_percent
        , battery_soh_unit
        , condition_grade
        , observed_at
        , observed_at_ts
        , assessment_completed_at
        , assessment_completed_at_ts
        , available_to_model_at
        , available_to_model_at_ts
    from
        typed

)

select
    source_record_id
    , source_system
    , source_batch_id
    , schema_version
    , schema_version_num
    , synthetic_vin
    , request_id
    , source_updated_at
    , source_updated_at_ts
    , ingested_at
    , ingested_at_ts
    , assessment_id
    , assessment_version
    , assessment_version_num
    , assessment_status
    , assessment_method_version
    , vehicle_model_family
    , vehicle_segment
    , model_year
    , model_year_num
    , assessed_odometer_value
    , assessed_odometer_value_num
    , assessed_odometer_unit
    , assessed_odometer_miles
    , assessed_odometer_kilometers
    , battery_soh_value
    , battery_soh_percent
    , battery_soh_unit
    , condition_grade
    , observed_at
    , observed_at_ts
    , assessment_completed_at
    , assessment_completed_at_ts
    , available_to_model_at
    , available_to_model_at_ts
from
    final
