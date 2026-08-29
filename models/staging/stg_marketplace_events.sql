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
        , auction_id
        , event_sequence
        , event_type
        , event_at
        , scheduled_close_at
        , bid_id
        , dealer_id
        , transaction_id
        , event_amount
        , event_amount_unit
        , currency_code
        , amount_role
        , auction_result_code
    from
        {{ ref('raw_marketplace_events') }}

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
        , auction_id
        , event_sequence
        , cast(event_sequence as number(10, 0)) as event_sequence_num
        , event_type
        , event_at
        , cast(event_at as timestamp_ntz) as event_at_ts
        , scheduled_close_at
        , cast(scheduled_close_at as timestamp_ntz) as scheduled_close_at_ts
        , bid_id
        , dealer_id
        , transaction_id
        , event_amount
        , event_amount_unit
        , currency_code
        , amount_role
        , auction_result_code
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
        , auction_id
        , event_sequence
        , event_sequence_num
        , event_type
        , event_at
        , event_at_ts
        , scheduled_close_at
        , scheduled_close_at_ts
        , bid_id
        , dealer_id
        , transaction_id
        , event_amount
        , case
            when event_amount_unit = 'usd'
                then cast(event_amount as number(18, 2))
            when event_amount_unit = 'usd_cent'
                then cast(event_amount / 100 as number(18, 2))
        end as event_amount_usd
        , case
            when event_amount_unit = 'usd'
                then cast(round(event_amount * 100, 0) as number(20, 0))
            when event_amount_unit = 'usd_cent'
                then cast(round(event_amount, 0) as number(20, 0))
        end as event_amount_cents
        , event_amount_unit
        , currency_code
        , amount_role
        , auction_result_code
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
        , auction_id
        , event_sequence
        , event_sequence_num
        , event_type
        , event_at
        , event_at_ts
        , scheduled_close_at
        , scheduled_close_at_ts
        , bid_id
        , dealer_id
        , transaction_id
        , event_amount
        , event_amount_usd
        , event_amount_cents
        , event_amount_unit
        , currency_code
        , amount_role
        , auction_result_code
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
    , auction_id
    , event_sequence
    , event_sequence_num
    , event_type
    , event_at
    , event_at_ts
    , scheduled_close_at
    , scheduled_close_at_ts
    , bid_id
    , dealer_id
    , transaction_id
    , event_amount
    , event_amount_usd
    , event_amount_cents
    , event_amount_unit
    , currency_code
    , amount_role
    , auction_result_code
from
    final
