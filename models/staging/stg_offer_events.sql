{{
    config(
        materialized='incremental',
        incremental_strategy='append'
    )
}}

with source as (

    select *
    from {{ ref('raw_offer_events') }}

    {% if is_incremental() %}
        where ingested_at > (select max(ingested_at) from {{ this }})
    {% endif %}

),

normalized as (

    select
        source_record_id,
        source_event_id,
        offer_id,
        request_id,
        source_system,
        source_batch_id,
        schema_version,
        event_type,
        event_sequence,
        offer_version,
        event_at,
        source_updated_at,
        ingested_at,
        offer_amount,
        offer_amount_unit,
        currency_code,
        expires_at,
        reason_code,
        cast(
            case
                when offer_amount_unit = 'dollars' then offer_amount
                when offer_amount_unit = 'cents' then offer_amount / 100
            end
            as number(38, 2)
        ) as offer_amount_dollars
    from source

)

select
    source_record_id,
    source_event_id,
    offer_id,
    request_id,
    source_system,
    source_batch_id,
    schema_version,
    event_type,
    event_sequence,
    offer_version,
    event_at,
    source_updated_at,
    ingested_at,
    offer_amount,
    offer_amount_unit,
    currency_code,
    expires_at,
    reason_code,
    offer_amount_dollars
from normalized
