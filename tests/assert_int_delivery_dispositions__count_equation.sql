with physical_counts as (

    select
        source,
        count(*) as physical_count
    from (
        select 'raw_valuation_requests' as source from {{ ref('stg_valuation_requests') }}
        union all
        select 'raw_vehicle_assessments' as source from {{ ref('stg_vehicle_assessments') }}
        union all
        select 'raw_offer_events' as source from {{ ref('stg_offer_events') }}
        union all
        select 'raw_marketplace_events' as source from {{ ref('stg_marketplace_events') }}
    ) as physical_sources
    group by source

),

disposition_counts as (

    select
        source,
        count_if(disposition = 'accepted') as accepted_count,
        count_if(disposition = 'duplicate') as duplicate_count,
        count_if(disposition = 'quarantined') as quarantined_count
    from {{ ref('int_delivery_dispositions') }}
    group by source

)

select
    physical_counts.source,
    physical_counts.physical_count,
    disposition_counts.accepted_count,
    disposition_counts.duplicate_count,
    disposition_counts.quarantined_count
from physical_counts
inner join disposition_counts
    on physical_counts.source = disposition_counts.source
where physical_counts.physical_count
    <> disposition_counts.accepted_count
        + disposition_counts.duplicate_count
        + disposition_counts.quarantined_count
