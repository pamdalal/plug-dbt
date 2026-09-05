select
    request_id
    , current_assessment_id
    , current_assessment_status
    , current_assessment_source_record_id
from
    {{ ref('dim_valuations') }}
where
    (
        current_assessment_source_record_id is null
        and (
            current_assessment_id is not null
            or current_assessment_schema_version is not null
            or current_assessment_version is not null
            or current_assessment_status is not null
            or current_assessment_method_version is not null
            or vehicle_model_family is not null
            or vehicle_segment is not null
            or model_year is not null
            or assessed_odometer_value is not null
            or assessed_odometer_unit is not null
            or assessed_odometer_miles is not null
            or assessed_odometer_kilometers is not null
            or battery_soh_percent is not null
            or condition_grade is not null
            or observed_at is not null
            or assessment_completed_at is not null
            or available_to_model_at is not null
            or current_assessment_source_updated_at is not null
        )
    )
    or (
        current_assessment_status = 'failed'
        and (
            vehicle_model_family is not null
            or vehicle_segment is not null
            or model_year is not null
            or assessed_odometer_value is not null
            or assessed_odometer_unit is not null
            or assessed_odometer_miles is not null
            or assessed_odometer_kilometers is not null
            or battery_soh_percent is not null
            or condition_grade is not null
            or observed_at is not null
        )
    )
