{{ config(materialized='table') }}

with valuation_request_events as (

    select
        'valuation_request' as event_type,
        'submitted' as event_name,
        submitted_at as event_at,
        ingested_at,
        source_record_id,
        md5(
            to_json(
                array_construct(
                    'valuation_request_submitted',
                    source_system,
                    request_id
                )
            )
        ) as sk
    from {{ ref('stg_valuation_requests') }}

),

offer_events as (

    select
        'offer' as event_type,
        event_type as event_name,
        event_at,
        ingested_at,
        source_record_id,
        md5(
            to_json(
                array_construct(
                    'offer_business_event',
                    source_system,
                    offer_id,
                    event_sequence
                )
            )
        ) as sk
    from {{ ref('stg_offer_events') }}

),

event_deliveries as (

    select
        event_type,
        event_name,
        event_at,
        ingested_at,
        source_record_id,
        sk
    from valuation_request_events

    union all

    select
        event_type,
        event_name,
        event_at,
        ingested_at,
        source_record_id,
        sk
    from offer_events

),

deduplicated as (

    select
        sk,
        event_type,
        event_name,
        event_at
    from event_deliveries
    qualify row_number() over (
        partition by sk
        order by
            ingested_at,
            source_record_id
    ) = 1

)

select
    sk,
    event_type,
    event_name,
    event_at
from deduplicated
