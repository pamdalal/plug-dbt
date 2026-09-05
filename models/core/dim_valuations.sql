{{ config(
    materialized = 'table'
) }}

with valuation_requests as (

    select
        ingested_at_ts
        , market_region
        , odometer_kilometers
        , odometer_miles
        , odometer_unit
        , odometer_value_num
        , request_id
        , seller_id
        , source_record_id
        , source_updated_at_ts
        , submission_channel
        , submitted_at_ts
        , synthetic_vin
    from
        {{ ref('stg_valuation_requests') }}

)

, current_requests as (

    select
        market_region
        , odometer_kilometers
        , odometer_miles
        , odometer_unit
        , odometer_value_num
        , request_id
        , seller_id
        , source_record_id
        , source_updated_at_ts
        , submission_channel
        , submitted_at_ts
        , synthetic_vin
    from
        valuation_requests
    qualify
        row_number() over (
            partition by request_id
            order by
                source_updated_at_ts desc
                , ingested_at_ts desc
                , source_record_id desc
        ) = 1

)

, vehicle_assessments as (

    select
        assessed_odometer_kilometers
        , assessed_odometer_miles
        , assessed_odometer_unit
        , assessed_odometer_value_num
        , assessment_completed_at_ts
        , assessment_id
        , assessment_method_version
        , assessment_status
        , assessment_version_num
        , available_to_model_at_ts
        , battery_soh_percent
        , condition_grade
        , ingested_at_ts
        , model_year_num
        , observed_at_ts
        , request_id
        , schema_version_num
        , source_record_id
        , source_updated_at_ts
        , vehicle_model_family
        , vehicle_segment
    from
        {{ ref('stg_vehicle_assessments') }}

)

, current_assessments as (

    select
        assessed_odometer_kilometers
        , assessed_odometer_miles
        , assessed_odometer_unit
        , assessed_odometer_value_num
        , assessment_completed_at_ts
        , assessment_id
        , assessment_method_version
        , assessment_status
        , assessment_version_num
        , available_to_model_at_ts
        , battery_soh_percent
        , condition_grade
        , model_year_num
        , observed_at_ts
        , request_id
        , schema_version_num
        , source_record_id
        , source_updated_at_ts
        , vehicle_model_family
        , vehicle_segment
    from
        vehicle_assessments
    qualify
        row_number() over (
            partition by request_id
            order by
                source_updated_at_ts desc
                , assessment_version_num desc
                , ingested_at_ts desc
                , source_record_id desc
        ) = 1

)

, final as (

    select
        requests.request_id
        , requests.synthetic_vin
        , requests.seller_id
        , requests.submission_channel
        , requests.market_region
        , requests.submitted_at_ts as submitted_at
        , requests.odometer_value_num as submitted_odometer_value
        , requests.odometer_unit as submitted_odometer_unit
        , requests.odometer_miles as submitted_odometer_miles
        , requests.odometer_kilometers as submitted_odometer_kilometers
        , requests.source_updated_at_ts as current_request_source_updated_at
        , requests.source_record_id as current_request_source_record_id
        , assessments.assessment_id as current_assessment_id
        , assessments.schema_version_num as current_assessment_schema_version
        , assessments.assessment_version_num as current_assessment_version
        , assessments.assessment_status as current_assessment_status
        , assessments.assessment_method_version as current_assessment_method_version
        , assessments.vehicle_model_family
        , assessments.vehicle_segment
        , assessments.model_year_num as model_year
        , assessments.assessed_odometer_value_num as assessed_odometer_value
        , assessments.assessed_odometer_unit
        , assessments.assessed_odometer_miles
        , assessments.assessed_odometer_kilometers
        , assessments.battery_soh_percent
        , assessments.condition_grade
        , assessments.observed_at_ts as observed_at
        , assessments.assessment_completed_at_ts as assessment_completed_at
        , assessments.available_to_model_at_ts as available_to_model_at
        , assessments.source_updated_at_ts as current_assessment_source_updated_at
        , assessments.source_record_id as current_assessment_source_record_id
    from
        current_requests as requests
    left join
        current_assessments as assessments
        on requests.request_id = assessments.request_id

)

select
    request_id
    , synthetic_vin
    , seller_id
    , submission_channel
    , market_region
    , submitted_at
    , submitted_odometer_value
    , submitted_odometer_unit
    , submitted_odometer_miles
    , submitted_odometer_kilometers
    , current_request_source_updated_at
    , current_request_source_record_id
    , current_assessment_id
    , current_assessment_schema_version
    , current_assessment_version
    , current_assessment_status
    , current_assessment_method_version
    , vehicle_model_family
    , vehicle_segment
    , model_year
    , assessed_odometer_value
    , assessed_odometer_unit
    , assessed_odometer_miles
    , assessed_odometer_kilometers
    , battery_soh_percent
    , condition_grade
    , observed_at
    , assessment_completed_at
    , available_to_model_at
    , current_assessment_source_updated_at
    , current_assessment_source_record_id
from
    final
