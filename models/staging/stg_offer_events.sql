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
        , source_event_id
        , offer_id
        , event_type
        , event_sequence
        , offer_version
        , event_at
        , reason_code
        , pricing_evaluation_id
        , feature_cutoff_at
        , pricing_evaluated_at
        , pricing_model_version
        , pricing_policy_version
        , assessment_id_used
        , assessment_version_used
        , predicted_wholesale_value_amount
        , net_policy_adjustment_amount
        , seller_offer_amount
        , pricing_amount_unit
        , pricing_currency_code
        , expires_at
    from
        {{ ref('raw_offer_events') }}

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
        , source_event_id
        , offer_id
        , event_type
        , event_sequence
        , cast(event_sequence as number(10, 0)) as event_sequence_num
        , offer_version
        , cast(offer_version as number(10, 0)) as offer_version_num
        , event_at
        , cast(event_at as timestamp_ntz) as event_at_ts
        , reason_code
        , pricing_evaluation_id
        , feature_cutoff_at
        , cast(feature_cutoff_at as timestamp_ntz) as feature_cutoff_at_ts
        , pricing_evaluated_at
        , cast(pricing_evaluated_at as timestamp_ntz) as pricing_evaluated_at_ts
        , pricing_model_version
        , pricing_policy_version
        , assessment_id_used
        , assessment_version_used
        , cast(assessment_version_used as number(10, 0)) as assessment_version_used_num
        , predicted_wholesale_value_amount
        , net_policy_adjustment_amount
        , seller_offer_amount
        , pricing_amount_unit
        , pricing_currency_code
        , expires_at
        , cast(expires_at as timestamp_ntz) as expires_at_ts
    from
        source

)

, normalized as (

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
        , source_event_id
        , offer_id
        , event_type
        , event_sequence
        , event_sequence_num
        , offer_version
        , offer_version_num
        , event_at
        , event_at_ts
        , reason_code
        , pricing_evaluation_id
        , feature_cutoff_at
        , feature_cutoff_at_ts
        , pricing_evaluated_at
        , pricing_evaluated_at_ts
        , pricing_model_version
        , pricing_policy_version
        , assessment_id_used
        , assessment_version_used
        , assessment_version_used_num
        , predicted_wholesale_value_amount
        , case
            when pricing_amount_unit = 'usd'
                then cast(predicted_wholesale_value_amount as number(18, 2))
            when pricing_amount_unit = 'usd_cent'
                then cast(predicted_wholesale_value_amount / 100 as number(18, 2))
        end as predicted_wholesale_value_amount_usd
        , case
            when pricing_amount_unit = 'usd'
                then cast(round(predicted_wholesale_value_amount * 100, 0) as number(20, 0))
            when pricing_amount_unit = 'usd_cent'
                then cast(round(predicted_wholesale_value_amount, 0) as number(20, 0))
        end as predicted_wholesale_value_amount_cents
        , net_policy_adjustment_amount
        , case
            when pricing_amount_unit = 'usd'
                then cast(net_policy_adjustment_amount as number(18, 2))
            when pricing_amount_unit = 'usd_cent'
                then cast(net_policy_adjustment_amount / 100 as number(18, 2))
        end as net_policy_adjustment_amount_usd
        , case
            when pricing_amount_unit = 'usd'
                then cast(round(net_policy_adjustment_amount * 100, 0) as number(20, 0))
            when pricing_amount_unit = 'usd_cent'
                then cast(round(net_policy_adjustment_amount, 0) as number(20, 0))
        end as net_policy_adjustment_amount_cents
        , seller_offer_amount
        , case
            when pricing_amount_unit = 'usd'
                then cast(seller_offer_amount as number(18, 2))
            when pricing_amount_unit = 'usd_cent'
                then cast(seller_offer_amount / 100 as number(18, 2))
        end as seller_offer_amount_usd
        , case
            when pricing_amount_unit = 'usd'
                then cast(round(seller_offer_amount * 100, 0) as number(20, 0))
            when pricing_amount_unit = 'usd_cent'
                then cast(round(seller_offer_amount, 0) as number(20, 0))
        end as seller_offer_amount_cents
        , pricing_amount_unit
        , pricing_currency_code
        , expires_at
        , expires_at_ts
    from
        typed

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
        , source_event_id
        , offer_id
        , event_type
        , event_sequence
        , event_sequence_num
        , offer_version
        , offer_version_num
        , event_at
        , event_at_ts
        , reason_code
        , pricing_evaluation_id
        , feature_cutoff_at
        , feature_cutoff_at_ts
        , pricing_evaluated_at
        , pricing_evaluated_at_ts
        , pricing_model_version
        , pricing_policy_version
        , assessment_id_used
        , assessment_version_used
        , assessment_version_used_num
        , predicted_wholesale_value_amount
        , predicted_wholesale_value_amount_usd
        , predicted_wholesale_value_amount_cents
        , net_policy_adjustment_amount
        , net_policy_adjustment_amount_usd
        , net_policy_adjustment_amount_cents
        , seller_offer_amount
        , seller_offer_amount_usd
        , seller_offer_amount_cents
        , pricing_amount_unit
        , pricing_currency_code
        , expires_at
        , expires_at_ts
    from
        normalized

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
    , source_event_id
    , offer_id
    , event_type
    , event_sequence
    , event_sequence_num
    , offer_version
    , offer_version_num
    , event_at
    , event_at_ts
    , reason_code
    , pricing_evaluation_id
    , feature_cutoff_at
    , feature_cutoff_at_ts
    , pricing_evaluated_at
    , pricing_evaluated_at_ts
    , pricing_model_version
    , pricing_policy_version
    , assessment_id_used
    , assessment_version_used
    , assessment_version_used_num
    , predicted_wholesale_value_amount
    , predicted_wholesale_value_amount_usd
    , predicted_wholesale_value_amount_cents
    , net_policy_adjustment_amount
    , net_policy_adjustment_amount_usd
    , net_policy_adjustment_amount_cents
    , seller_offer_amount
    , seller_offer_amount_usd
    , seller_offer_amount_cents
    , pricing_amount_unit
    , pricing_currency_code
    , expires_at
    , expires_at_ts
from
    final
