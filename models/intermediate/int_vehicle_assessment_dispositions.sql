{{ config(materialized='view') }}

with evaluated as (

    select
        *,
        (
            source_record_id is not null
            and source_system = 'vehicle_assessment'
            and source_batch_id is not null
            and schema_version is not null
            and synthetic_vin is not null
            and request_id is not null
            and source_updated_at_ts is not null
            and ingested_at_ts is not null
            and source_updated_at_ts <= ingested_at_ts
            and ingested_at_ts < to_timestamp_tz('2026-07-31T00:00:00Z')
        ) as physical_envelope_valid,
        (
            schema_version = '1.0'
            and assessment_id is not null
            and assessment_version_numeric in (1, 2)
            and assessment_status in ('usable', 'failed')
            and assessment_method_version in (
                'method_baseline',
                'method_current'
            )
            and assessment_completed_at_ts is not null
            and available_to_model_at_ts is not null
            and assessment_completed_at_ts <= source_updated_at_ts
            and source_updated_at_ts <= available_to_model_at_ts
            and available_to_model_at_ts
                < to_timestamp_tz('2026-07-31T00:00:00Z')
            and (
                (
                    assessment_status = 'usable'
                    and vehicle_model_family in (
                        'chevrolet_bolt_ev',
                        'nissan_leaf',
                        'tesla_model_3',
                        'tesla_model_y',
                        'hyundai_ioniq_5',
                        'ford_mustang_mach_e',
                        'ford_f150_lightning'
                    )
                    and vehicle_segment = case vehicle_model_family
                        when 'chevrolet_bolt_ev' then 'hatchback'
                        when 'nissan_leaf' then 'hatchback'
                        when 'tesla_model_3' then 'sedan'
                        when 'tesla_model_y' then 'crossover'
                        when 'hyundai_ioniq_5' then 'crossover'
                        when 'ford_mustang_mach_e' then 'crossover'
                        when 'ford_f150_lightning' then 'pickup'
                    end
                    and model_year_numeric between 2012 and 2026
                    and assessed_odometer_value_numeric > 0
                    and assessed_odometer_unit in ('mi', 'km')
                    and battery_soh_percent between 50.0 and 100.0
                    and battery_soh_unit = 'percent'
                    and condition_grade in ('clean', 'average', 'rough')
                    and observed_at_ts is not null
                    and observed_at_ts <= assessment_completed_at_ts
                )
                or (
                    assessment_status = 'failed'
                    and vehicle_model_family is null
                    and vehicle_segment is null
                    and model_year is null
                    and assessed_odometer_value is null
                    and assessed_odometer_unit is null
                    and battery_soh_value is null
                    and battery_soh_unit is null
                    and condition_grade is null
                    and observed_at is null
                )
            )
        ) as supported_row_valid,
        md5(
            to_json(
                array_construct(
                    schema_version,
                    synthetic_vin,
                    request_id,
                    date_part(epoch_second, source_updated_at_ts),
                    assessment_id,
                    assessment_version,
                    assessment_status,
                    assessment_method_version,
                    vehicle_model_family,
                    vehicle_segment,
                    model_year,
                    assessed_odometer_value,
                    assessed_odometer_unit,
                    battery_soh_value,
                    battery_soh_unit,
                    condition_grade,
                    date_part(epoch_second, observed_at_ts),
                    date_part(epoch_second, assessment_completed_at_ts),
                    date_part(epoch_second, available_to_model_at_ts)
                )
            )
        ) as replay_payload_hash
    from {{ ref('stg_vehicle_assessments') }}

),

replay_candidates as (

    select *
    from evaluated
    where physical_envelope_valid
        and supported_row_valid

),

replay_groups as (

    select
        assessment_id,
        assessment_version,
        source_system,
        count(distinct replay_payload_hash) as replay_payload_count
    from replay_candidates
    group by
        assessment_id,
        assessment_version,
        source_system

),

ranked as (

    select
        replay_candidates.delivery_sk,
        replay_groups.replay_payload_count,
        row_number() over (
            partition by
                replay_candidates.source_system,
                replay_candidates.assessment_id,
                replay_candidates.assessment_version
            order by
                replay_candidates.ingested_at_ts,
                replay_candidates.source_record_id
        ) as replay_delivery_rank,
        first_value(replay_candidates.delivery_sk) over (
            partition by
                replay_candidates.source_system,
                replay_candidates.assessment_id,
                replay_candidates.assessment_version
            order by
                replay_candidates.ingested_at_ts,
                replay_candidates.source_record_id
        ) as survivor_delivery_sk
    from replay_candidates
    inner join replay_groups
        on replay_candidates.source_system = replay_groups.source_system
        and replay_candidates.assessment_id = replay_groups.assessment_id
        and replay_candidates.assessment_version = replay_groups.assessment_version

),

base_dispositions as (

    select
        evaluated.*,
        case
            when not evaluated.physical_envelope_valid then 'quarantined'
            when evaluated.schema_version <> '1.0' then 'quarantined'
            when not coalesce(evaluated.supported_row_valid, false)
                then 'quarantined'
            when ranked.replay_payload_count > 1 then 'quarantined'
            when ranked.replay_delivery_rank = 1 then 'accepted'
            else 'duplicate'
        end as base_disposition,
        case
            when not evaluated.physical_envelope_valid then 'schema_validation_error'
            when evaluated.schema_version <> '1.0' then 'unsupported_schema_version'
            when not coalesce(evaluated.supported_row_valid, false)
                then 'schema_validation_error'
            when ranked.replay_payload_count > 1 then 'immutable_key_conflict'
            when ranked.replay_delivery_rank > 1 then 'exact_replay'
        end as base_disposition_reason,
        case
            when ranked.replay_payload_count = 1
                and ranked.replay_delivery_rank > 1
                then ranked.survivor_delivery_sk
        end as survivor_delivery_sk
    from evaluated
    left join ranked
        on evaluated.delivery_sk = ranked.delivery_sk

)

select
    base_dispositions.delivery_sk,
    base_dispositions.request_id,
    base_dispositions.survivor_delivery_sk,
    'raw_vehicle_assessments' as source,
    case
        when base_dispositions.base_disposition <> 'accepted'
            then base_dispositions.base_disposition
        when requests.request_id is null then 'quarantined'
        when base_dispositions.synthetic_vin <> requests.synthetic_vin
            then 'quarantined'
        else 'accepted'
    end as disposition,
    case
        when base_dispositions.base_disposition <> 'accepted'
            then base_dispositions.base_disposition_reason
        when requests.request_id is null then 'orphaned_request'
        when base_dispositions.synthetic_vin <> requests.synthetic_vin
            then 'identity_mismatch'
    end as disposition_reason
from base_dispositions
left join {{ ref('int_canonical_valuation_requests') }} as requests
    on base_dispositions.request_id = requests.request_id
