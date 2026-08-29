{{ config(materialized='view') }}

with evaluated as (

    select
        *,
        (
            source_record_id is not null
            and source_system = 'offer_service'
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
            and source_event_id is not null
            and offer_id is not null
            and event_type in (
                'issued',
                'revised',
                'accepted',
                'declined',
                'expired',
                'withdrawn'
            )
            and event_sequence_numeric > 0
            and offer_version_numeric in (1, 2)
            and event_at_ts is not null
            and event_at_ts <= source_updated_at_ts
            and event_at_ts < to_timestamp_tz('2026-07-31T00:00:00Z')
            and (
                (
                    event_type in ('issued', 'revised')
                    and pricing_evaluation_id is not null
                    and feature_cutoff_at_ts is not null
                    and pricing_evaluated_at_ts is not null
                    and pricing_model_version in (
                        'model_baseline',
                        'model_challenger'
                    )
                    and pricing_policy_version = 'policy_v1'
                    and assessment_id_used is not null
                    and assessment_version_used_numeric in (1, 2)
                    and predicted_wholesale_value_usd_cents > 0
                    and net_policy_adjustment_usd_cents is not null
                    and seller_offer_usd_cents > 0
                    and pricing_amount_unit in ('usd', 'usd_cent')
                    and pricing_currency_code = 'USD'
                    and expires_at_ts is not null
                    and feature_cutoff_at_ts <= pricing_evaluated_at_ts
                    and pricing_evaluated_at_ts <= event_at_ts
                    and event_at_ts <= expires_at_ts
                    and seller_offer_usd_cents
                        = predicted_wholesale_value_usd_cents
                            + net_policy_adjustment_usd_cents
                    and (
                        (
                            event_type = 'issued'
                            and event_sequence_numeric = 1
                            and offer_version_numeric = 1
                            and reason_code is null
                        )
                        or (
                            event_type = 'revised'
                            and event_sequence_numeric = 2
                            and offer_version_numeric = 2
                            and reason_code in (
                                'assessment_correction',
                                'time_based_reprice'
                            )
                        )
                    )
                )
                or (
                    event_type in (
                        'accepted',
                        'declined',
                        'expired',
                        'withdrawn'
                    )
                    and pricing_evaluation_id is null
                    and feature_cutoff_at is null
                    and pricing_evaluated_at is null
                    and pricing_model_version is null
                    and pricing_policy_version is null
                    and assessment_id_used is null
                    and assessment_version_used is null
                    and predicted_wholesale_value_amount is null
                    and net_policy_adjustment_amount is null
                    and seller_offer_amount is null
                    and pricing_amount_unit is null
                    and pricing_currency_code is null
                    and expires_at is null
                    and (
                        (
                            event_type in ('accepted', 'expired')
                            and reason_code is null
                        )
                        or (
                            event_type = 'declined'
                            and reason_code = 'seller_declined'
                        )
                        or (
                            event_type = 'withdrawn'
                            and reason_code = 'seller_withdrew'
                        )
                    )
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
                    source_event_id,
                    offer_id,
                    event_type,
                    event_sequence,
                    offer_version,
                    date_part(epoch_second, event_at_ts),
                    reason_code,
                    pricing_evaluation_id,
                    date_part(epoch_second, feature_cutoff_at_ts),
                    date_part(epoch_second, pricing_evaluated_at_ts),
                    pricing_model_version,
                    pricing_policy_version,
                    assessment_id_used,
                    assessment_version_used,
                    predicted_wholesale_value_amount,
                    net_policy_adjustment_amount,
                    seller_offer_amount,
                    pricing_amount_unit,
                    pricing_currency_code,
                    date_part(epoch_second, expires_at_ts)
                )
            )
        ) as replay_payload_hash
    from {{ ref('stg_offer_events') }}

),

replay_candidates as (

    select *
    from evaluated
    where physical_envelope_valid
        and supported_row_valid

),

replay_groups as (

    select
        event_sequence,
        offer_id,
        source_system,
        count(distinct replay_payload_hash) as replay_payload_count
    from replay_candidates
    group by
        event_sequence,
        offer_id,
        source_system

),

ranked as (

    select
        replay_candidates.delivery_sk,
        replay_groups.replay_payload_count,
        row_number() over (
            partition by
                replay_candidates.source_system,
                replay_candidates.offer_id,
                replay_candidates.event_sequence
            order by
                replay_candidates.ingested_at_ts,
                replay_candidates.source_record_id
        ) as replay_delivery_rank,
        first_value(replay_candidates.delivery_sk) over (
            partition by
                replay_candidates.source_system,
                replay_candidates.offer_id,
                replay_candidates.event_sequence
            order by
                replay_candidates.ingested_at_ts,
                replay_candidates.source_record_id
        ) as survivor_delivery_sk
    from replay_candidates
    inner join replay_groups
        on replay_candidates.source_system = replay_groups.source_system
        and replay_candidates.offer_id = replay_groups.offer_id
        and replay_candidates.event_sequence = replay_groups.event_sequence

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
    'raw_offer_events' as source,
    case
        when base_dispositions.base_disposition <> 'accepted'
            then base_dispositions.base_disposition
        when requests.request_id is null then 'quarantined'
        when base_dispositions.synthetic_vin <> requests.synthetic_vin
            then 'quarantined'
        when base_dispositions.event_type in ('issued', 'revised')
            and (
                assessments.delivery_sk is null
                or assessments.assessment_status <> 'usable'
                or assessments.available_to_model_at_ts
                    > base_dispositions.feature_cutoff_at_ts
            )
            then 'quarantined'
        else 'accepted'
    end as disposition,
    case
        when base_dispositions.base_disposition <> 'accepted'
            then base_dispositions.base_disposition_reason
        when requests.request_id is null then 'orphaned_request'
        when base_dispositions.synthetic_vin <> requests.synthetic_vin
            then 'identity_mismatch'
        when base_dispositions.event_type in ('issued', 'revised')
            and (
                assessments.delivery_sk is null
                or assessments.assessment_status <> 'usable'
                or assessments.available_to_model_at_ts
                    > base_dispositions.feature_cutoff_at_ts
            )
            then 'assessment_unavailable_at_feature_cutoff'
    end as disposition_reason
from base_dispositions
left join {{ ref('int_canonical_valuation_requests') }} as requests
    on base_dispositions.request_id = requests.request_id
left join {{ ref('int_canonical_vehicle_assessments') }} as assessments
    on base_dispositions.request_id = assessments.request_id
    and base_dispositions.assessment_id_used = assessments.assessment_id
    and base_dispositions.assessment_version_used = assessments.assessment_version
