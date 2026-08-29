{{ config(materialized='view') }}

with evaluated as (

    select
        *,
        (
            source_record_id is not null
            and source_system = 'valuation_portal'
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
            and seller_id is not null
            and submission_channel in ('web', 'mobile')
            and market_region in (
                'great_lakes',
                'mid_atlantic',
                'mountain_west',
                'pacific_coast'
            )
            and odometer_value_numeric > 0
            and odometer_unit in ('mi', 'km')
            and submitted_at_ts is not null
            and submitted_at_ts <= source_updated_at_ts
            and submitted_at_ts < to_timestamp_tz('2026-07-31T00:00:00Z')
        ) as supported_row_valid,
        md5(
            to_json(
                array_construct(
                    schema_version,
                    synthetic_vin,
                    request_id,
                    date_part(epoch_second, source_updated_at_ts),
                    seller_id,
                    submission_channel,
                    market_region,
                    odometer_value,
                    odometer_unit,
                    date_part(epoch_second, submitted_at_ts)
                )
            )
        ) as replay_payload_hash
    from {{ ref('stg_valuation_requests') }}

),

replay_candidates as (

    select *
    from evaluated
    where physical_envelope_valid
        and supported_row_valid

),

replay_groups as (

    select
        source_system,
        request_id,
        count(distinct replay_payload_hash) as replay_payload_count
    from replay_candidates
    group by
        source_system,
        request_id

),

ranked as (

    select
        replay_candidates.delivery_sk,
        replay_groups.replay_payload_count,
        row_number() over (
            partition by
                replay_candidates.source_system,
                replay_candidates.request_id
            order by
                replay_candidates.ingested_at_ts,
                replay_candidates.source_record_id
        ) as replay_delivery_rank,
        first_value(replay_candidates.delivery_sk) over (
            partition by
                replay_candidates.source_system,
                replay_candidates.request_id
            order by
                replay_candidates.ingested_at_ts,
                replay_candidates.source_record_id
        ) as survivor_delivery_sk
    from replay_candidates
    inner join replay_groups
        on replay_candidates.source_system = replay_groups.source_system
        and replay_candidates.request_id = replay_groups.request_id

)

select
    evaluated.delivery_sk,
    evaluated.request_id,
    'raw_valuation_requests' as source,
    case
        when ranked.replay_payload_count = 1
            and ranked.replay_delivery_rank > 1
            then ranked.survivor_delivery_sk
    end as survivor_delivery_sk,
    case
        when not evaluated.physical_envelope_valid then 'quarantined'
        when evaluated.schema_version <> '1.0' then 'quarantined'
        when not coalesce(evaluated.supported_row_valid, false) then 'quarantined'
        when ranked.replay_payload_count > 1 then 'quarantined'
        when ranked.replay_delivery_rank = 1 then 'accepted'
        else 'duplicate'
    end as disposition,
    case
        when not evaluated.physical_envelope_valid then 'schema_validation_error'
        when evaluated.schema_version <> '1.0' then 'unsupported_schema_version'
        when not coalesce(evaluated.supported_row_valid, false)
            then 'schema_validation_error'
        when ranked.replay_payload_count > 1 then 'immutable_key_conflict'
        when ranked.replay_delivery_rank > 1 then 'exact_replay'
    end as disposition_reason
from evaluated
left join ranked
    on evaluated.delivery_sk = ranked.delivery_sk
