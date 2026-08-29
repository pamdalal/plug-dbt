with canonical_deliveries as (

    select
        delivery_sk,
        'raw_valuation_requests' as source
    from {{ ref('int_canonical_valuation_requests') }}

    union all

    select
        delivery_sk,
        'raw_vehicle_assessments' as source
    from {{ ref('int_canonical_vehicle_assessments') }}

    union all

    select
        delivery_sk,
        'raw_offer_events' as source
    from {{ ref('int_canonical_offer_events') }}

    union all

    select
        delivery_sk,
        'raw_marketplace_events' as source
    from {{ ref('int_canonical_marketplace_events') }}

),

accepted_dispositions as (

    select
        delivery_sk,
        source
    from {{ ref('int_delivery_dispositions') }}
    where disposition = 'accepted'

)

select
    coalesce(canonical_deliveries.source, accepted_dispositions.source) as source,
    coalesce(
        canonical_deliveries.delivery_sk,
        accepted_dispositions.delivery_sk
    ) as delivery_sk,
    canonical_deliveries.delivery_sk is null as missing_canonical_delivery,
    accepted_dispositions.delivery_sk is null as delivery_not_accepted
from canonical_deliveries
full outer join accepted_dispositions
    on canonical_deliveries.source = accepted_dispositions.source
    and canonical_deliveries.delivery_sk = accepted_dispositions.delivery_sk
where canonical_deliveries.delivery_sk is null
    or accepted_dispositions.delivery_sk is null
