{{ config(
    materialized = 'table'
) }}

with offer_events as (

    select
        assessment_id_used
        , assessment_version_used_num
        , event_at_ts
        , event_sequence_num
        , event_type
        , expires_at_ts
        , ingested_at_ts
        , net_policy_adjustment_amount_cents
        , offer_id
        , offer_version_num
        , predicted_wholesale_value_amount_cents
        , pricing_currency_code
        , pricing_evaluation_id
        , pricing_model_version
        , pricing_policy_version
        , reason_code
        , request_id
        , seller_offer_amount_cents
        , source_event_id
        , source_record_id
        , synthetic_vin
    from
        {{ ref('stg_offer_events') }}

)

, current_lifecycle_event as (

    select
        event_at_ts
        , event_sequence_num
        , event_type
        , offer_id
        , offer_version_num
        , reason_code
        , request_id
        , source_event_id
        , source_record_id
        , synthetic_vin

    from
        offer_events
    qualify
        row_number() over (
            partition by offer_id
            order by
                event_sequence_num desc
                , event_at_ts desc
                , ingested_at_ts desc
                , source_record_id desc
        ) = 1

)

, pricing_events as (

    select
        assessment_id_used
        , assessment_version_used_num
        , event_at_ts
        , event_sequence_num
        , event_type
        , expires_at_ts
        , ingested_at_ts
        , net_policy_adjustment_amount_cents
        , offer_id
        , offer_version_num
        , predicted_wholesale_value_amount_cents
        , pricing_currency_code
        , pricing_evaluation_id
        , pricing_model_version
        , pricing_policy_version
        , seller_offer_amount_cents
        , source_event_id
        , source_record_id
    from
        offer_events
    where
        event_type in ('issued', 'revised')

)

, latest_pricing_event as (

    select
        assessment_id_used
        , assessment_version_used_num
        , event_at_ts
        , event_type
        , expires_at_ts
        , net_policy_adjustment_amount_cents
        , offer_id
        , predicted_wholesale_value_amount_cents
        , pricing_currency_code
        , pricing_evaluation_id
        , pricing_model_version
        , pricing_policy_version
        , seller_offer_amount_cents
        , source_event_id
        , source_record_id
    from
        pricing_events
    qualify
        row_number() over (
            partition by offer_id
            order by
                offer_version_num desc
                , event_sequence_num desc
                , event_at_ts desc
                , ingested_at_ts desc
                , source_record_id desc
        ) = 1

)

, offer_milestones as (

    select
        offer_id
        , min(
            case
                when event_type = 'issued'
                    then event_at_ts
            end
        ) as offer_issued_at
    from
        offer_events
    group by
        offer_id

)

, final as (

    select
        latest_pricing.assessment_id_used
        , latest_pricing.assessment_version_used_num as assessment_version_used
        , current_event.event_at_ts as current_event_at
        , current_event.event_sequence_num as current_event_sequence
        , current_event.event_type as current_event_type
        , current_event.offer_version_num as current_offer_version
        , current_event.reason_code as current_reason_code
        , current_event.source_event_id as current_source_event_id
        , current_event.source_record_id as current_source_record_id
        , latest_pricing.expires_at_ts as expires_at
        , latest_pricing.event_at_ts as latest_pricing_event_at
        , latest_pricing.event_type as latest_pricing_event_type
        , latest_pricing.source_event_id as latest_pricing_source_event_id
        , latest_pricing.source_record_id as latest_pricing_source_record_id
        , latest_pricing.net_policy_adjustment_amount_cents
        , current_event.offer_id
        , milestones.offer_issued_at
        , latest_pricing.predicted_wholesale_value_amount_cents
        , latest_pricing.pricing_currency_code
        , latest_pricing.pricing_evaluation_id
        , latest_pricing.pricing_model_version
        , latest_pricing.pricing_policy_version
        , current_event.request_id
        , latest_pricing.seller_offer_amount_cents
        , current_event.synthetic_vin
    from
        current_lifecycle_event as current_event
    left join
        latest_pricing_event as latest_pricing
        on current_event.offer_id = latest_pricing.offer_id
    left join
        offer_milestones as milestones
        on current_event.offer_id = milestones.offer_id

)

select
    assessment_id_used
    , assessment_version_used
    , current_event_at
    , current_event_sequence
    , current_event_type
    , current_offer_version
    , current_reason_code
    , current_source_event_id
    , current_source_record_id
    , expires_at
    , latest_pricing_event_at
    , latest_pricing_event_type
    , latest_pricing_source_event_id
    , latest_pricing_source_record_id
    , net_policy_adjustment_amount_cents
    , offer_id
    , offer_issued_at
    , predicted_wholesale_value_amount_cents
    , pricing_currency_code
    , pricing_evaluation_id
    , pricing_model_version
    , pricing_policy_version
    , request_id
    , seller_offer_amount_cents
    , synthetic_vin
from
    final
