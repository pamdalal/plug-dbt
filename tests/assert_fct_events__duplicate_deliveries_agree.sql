with valuation_request_events as (

    select
        md5(
            to_json(
                array_construct(
                    'valuation_request_submitted',
                    source_system,
                    request_id
                )
            )
        ) as sk,
        'valuation_request' as event_type,
        'submitted' as event_name,
        submitted_at as event_at
    from {{ ref('stg_valuation_requests') }}

),

offer_events as (

    select
        md5(
            to_json(
                array_construct(
                    'offer_business_event',
                    source_system,
                    offer_id,
                    event_sequence
                )
            )
        ) as sk,
        'offer' as event_type,
        event_type as event_name,
        event_at
    from {{ ref('stg_offer_events') }}

),

event_deliveries as (

    select * from valuation_request_events
    union all
    select * from offer_events

)

select
    sk,
    count(*) as delivery_count,
    count(distinct event_type) as event_type_count,
    count(distinct event_name) as event_name_count,
    count(distinct event_at) as event_at_count
from event_deliveries
group by sk
having count(distinct event_type) > 1
    or count(distinct event_name) > 1
    or count(distinct event_at) > 1
