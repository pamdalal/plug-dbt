{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='fail'
    )
}}

with source as (

    select
        amount_role,
        auction_id,
        auction_result_code,
        bid_id,
        currency_code,
        dealer_id,
        event_amount,
        event_amount_unit,
        event_at,
        event_sequence,
        event_type,
        ingested_at,
        offer_id,
        request_id,
        scheduled_close_at,
        schema_version,
        source_batch_id,
        source_event_id,
        source_record_id,
        source_system,
        source_updated_at,
        synthetic_vin,
        transaction_id,
        try_to_decimal(event_amount, 38, 2) as event_amount_numeric,
        try_to_timestamp_tz(event_at) as event_at_ts,
        try_to_decimal(event_sequence, 38, 0) as event_sequence_numeric,
        to_timestamp_tz(ingested_at) as ingested_at_ts,
        try_to_timestamp_tz(scheduled_close_at) as scheduled_close_at_ts,
        try_to_timestamp_tz(source_updated_at) as source_updated_at_ts
    from {{ ref('raw_marketplace_events') }}

    {% if is_incremental() %}
        where (
            (select max(ingested_at_ts) from {{ this }}) is null
            or to_timestamp_tz(ingested_at)
                > (select max(ingested_at_ts) from {{ this }})
        )
    {% endif %}

),

normalized as (

    select
        amount_role,
        auction_id,
        auction_result_code,
        bid_id,
        currency_code,
        dealer_id,
        event_amount,
        event_amount_numeric,
        event_amount_unit,
        event_at,
        event_at_ts,
        event_sequence,
        event_sequence_numeric,
        event_type,
        ingested_at,
        ingested_at_ts,
        offer_id,
        request_id,
        scheduled_close_at,
        scheduled_close_at_ts,
        schema_version,
        source_batch_id,
        source_event_id,
        source_record_id,
        source_system,
        source_updated_at,
        source_updated_at_ts,
        synthetic_vin,
        transaction_id,
        false as event_amount_unit_normalized,
        cast(event_amount_numeric as number(38, 2)) as event_amount_usd,
        cast(
            event_amount_numeric * 100 as number(38, 0)
        ) as event_amount_usd_cents,
        md5(
            to_json(
                array_construct(
                    'raw_marketplace_events',
                    source_system,
                    source_record_id
                )
            )
        ) as delivery_sk,
        (
            not regexp_like(event_at, 'Z$')
            or not regexp_like(ingested_at, 'Z$')
            or coalesce(not regexp_like(scheduled_close_at, 'Z$'), false)
            or not regexp_like(source_updated_at, 'Z$')
        ) as has_non_z_timestamp_representation
    from source

)

select
    amount_role,
    auction_id,
    auction_result_code,
    bid_id,
    currency_code,
    dealer_id,
    delivery_sk,
    event_amount,
    event_amount_numeric,
    event_amount_unit,
    event_amount_unit_normalized,
    event_amount_usd,
    event_amount_usd_cents,
    event_at,
    event_at_ts,
    event_sequence,
    event_sequence_numeric,
    event_type,
    has_non_z_timestamp_representation,
    ingested_at,
    ingested_at_ts,
    offer_id,
    request_id,
    scheduled_close_at,
    scheduled_close_at_ts,
    schema_version,
    source_batch_id,
    source_event_id,
    source_record_id,
    source_system,
    source_updated_at,
    source_updated_at_ts,
    synthetic_vin,
    transaction_id
from normalized
