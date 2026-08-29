with physical_deliveries as (

    select
        delivery_sk,
        'raw_valuation_requests' as source
    from {{ ref('stg_valuation_requests') }}

    union all

    select
        delivery_sk,
        'raw_vehicle_assessments' as source
    from {{ ref('stg_vehicle_assessments') }}

    union all

    select
        delivery_sk,
        'raw_offer_events' as source
    from {{ ref('stg_offer_events') }}

    union all

    select
        delivery_sk,
        'raw_marketplace_events' as source
    from {{ ref('stg_marketplace_events') }}

)

select
    coalesce(physical_deliveries.source, dispositions.source) as source,
    coalesce(physical_deliveries.delivery_sk, dispositions.delivery_sk) as delivery_sk,
    physical_deliveries.delivery_sk is null as missing_physical_delivery,
    dispositions.delivery_sk is null as missing_disposition
from physical_deliveries
full outer join {{ ref('int_delivery_dispositions') }} as dispositions
    on physical_deliveries.source = dispositions.source
    and physical_deliveries.delivery_sk = dispositions.delivery_sk
where physical_deliveries.delivery_sk is null
    or dispositions.delivery_sk is null
