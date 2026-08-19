with duplicate_source_event_ids as (

    select
        source_event_id
    from {{ ref('raw_offer_events') }}
    group by source_event_id
    having count(*) > 1

)

select
    offers.source_record_id,
    offers.source_event_id,
    offers.offer_id,
    offers.request_id,
    offers.event_type,
    offers.event_sequence,
    offers.offer_version,
    offers.event_at,
    offers.source_batch_id,
    offers.source_updated_at,
    offers.ingested_at
from {{ ref('raw_offer_events') }} as offers
inner join duplicate_source_event_ids
    on offers.source_event_id = duplicate_source_event_ids.source_event_id
order by
    offers.source_event_id,
    offers.ingested_at,
    offers.source_record_id
