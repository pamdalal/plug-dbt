{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='fail'
    )
}}

with source as (

    select
        assessment_id_used,
        assessment_version_used,
        event_at,
        event_sequence,
        event_type,
        expires_at,
        feature_cutoff_at,
        ingested_at,
        net_policy_adjustment_amount,
        offer_id,
        offer_version,
        predicted_wholesale_value_amount,
        pricing_amount_unit,
        pricing_currency_code,
        pricing_evaluated_at,
        pricing_evaluation_id,
        pricing_model_version,
        pricing_policy_version,
        reason_code,
        request_id,
        schema_version,
        seller_offer_amount,
        source_batch_id,
        source_event_id,
        source_record_id,
        source_system,
        source_updated_at,
        synthetic_vin,
        try_to_decimal(assessment_version_used, 38, 0)
            as assessment_version_used_numeric,
        try_to_timestamp_tz(event_at) as event_at_ts,
        try_to_decimal(event_sequence, 38, 0) as event_sequence_numeric,
        try_to_timestamp_tz(expires_at) as expires_at_ts,
        try_to_timestamp_tz(feature_cutoff_at) as feature_cutoff_at_ts,
        to_timestamp_tz(ingested_at) as ingested_at_ts,
        try_to_decimal(net_policy_adjustment_amount, 38, 2)
            as net_policy_adjustment_amount_numeric,
        try_to_decimal(offer_version, 38, 0) as offer_version_numeric,
        try_to_decimal(predicted_wholesale_value_amount, 38, 2)
            as predicted_wholesale_value_amount_numeric,
        try_to_timestamp_tz(pricing_evaluated_at) as pricing_evaluated_at_ts,
        try_to_decimal(seller_offer_amount, 38, 2) as seller_offer_amount_numeric,
        try_to_timestamp_tz(source_updated_at) as source_updated_at_ts
    from {{ ref('raw_offer_events') }}

    {% if is_incremental() %}
        where (
            (select max(ingested_at_ts) from {{ this }}) is null
            or to_timestamp_tz(ingested_at)
                > (select max(ingested_at_ts) from {{ this }})
        )
    {% endif %}

)

select
    assessment_id_used,
    assessment_version_used,
    assessment_version_used_numeric,
    event_at,
    event_at_ts,
    event_sequence,
    event_sequence_numeric,
    event_type,
    expires_at,
    expires_at_ts,
    feature_cutoff_at,
    feature_cutoff_at_ts,
    ingested_at,
    ingested_at_ts,
    net_policy_adjustment_amount,
    net_policy_adjustment_amount_numeric,
    offer_id,
    offer_version,
    offer_version_numeric,
    predicted_wholesale_value_amount,
    predicted_wholesale_value_amount_numeric,
    pricing_amount_unit,
    pricing_currency_code,
    pricing_evaluated_at,
    pricing_evaluated_at_ts,
    pricing_evaluation_id,
    pricing_model_version,
    pricing_policy_version,
    reason_code,
    request_id,
    schema_version,
    seller_offer_amount,
    seller_offer_amount_numeric,
    source_batch_id,
    source_event_id,
    source_record_id,
    source_system,
    source_updated_at,
    source_updated_at_ts,
    synthetic_vin,
    md5(
        to_json(
            array_construct(
                'raw_offer_events',
                source_system,
                source_record_id
            )
        )
    ) as delivery_sk,
    (
        not regexp_like(event_at, 'Z$')
        or coalesce(not regexp_like(expires_at, 'Z$'), false)
        or coalesce(not regexp_like(feature_cutoff_at, 'Z$'), false)
        or not regexp_like(ingested_at, 'Z$')
        or coalesce(not regexp_like(pricing_evaluated_at, 'Z$'), false)
        or not regexp_like(source_updated_at, 'Z$')
    ) as has_non_z_timestamp_representation,
    cast(
        case
            when pricing_amount_unit = 'usd' then net_policy_adjustment_amount_numeric
            when pricing_amount_unit = 'usd_cent'
                then try_to_decimal(net_policy_adjustment_amount, 38, 0) / 100
        end
        as number(38, 2)
    ) as net_policy_adjustment_usd,
    cast(
        case
            when pricing_amount_unit = 'usd'
                then net_policy_adjustment_amount_numeric * 100
            when pricing_amount_unit = 'usd_cent'
                then try_to_decimal(net_policy_adjustment_amount, 38, 0)
        end
        as number(38, 0)
    ) as net_policy_adjustment_usd_cents,
    cast(
        case
            when pricing_amount_unit = 'usd' then predicted_wholesale_value_amount_numeric
            when pricing_amount_unit = 'usd_cent'
                then try_to_decimal(predicted_wholesale_value_amount, 38, 0) / 100
        end
        as number(38, 2)
    ) as predicted_wholesale_value_usd,
    cast(
        case
            when pricing_amount_unit = 'usd'
                then predicted_wholesale_value_amount_numeric * 100
            when pricing_amount_unit = 'usd_cent'
                then try_to_decimal(predicted_wholesale_value_amount, 38, 0)
        end
        as number(38, 0)
    ) as predicted_wholesale_value_usd_cents,
    pricing_amount_unit = 'usd_cent' as pricing_amount_unit_normalized,
    cast(
        case
            when pricing_amount_unit = 'usd' then seller_offer_amount_numeric
            when pricing_amount_unit = 'usd_cent'
                then try_to_decimal(seller_offer_amount, 38, 0) / 100
        end
        as number(38, 2)
    ) as seller_offer_usd,
    cast(
        case
            when pricing_amount_unit = 'usd' then seller_offer_amount_numeric * 100
            when pricing_amount_unit = 'usd_cent'
                then try_to_decimal(seller_offer_amount, 38, 0)
        end
        as number(38, 0)
    ) as seller_offer_usd_cents
from source
