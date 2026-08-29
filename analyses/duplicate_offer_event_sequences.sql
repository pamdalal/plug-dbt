with duplicate_event_sequences as (

    select
        offer_id,
        event_sequence
    from {{ ref('raw_offer_events') }}
    group by
        offer_id,
        event_sequence
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
inner join duplicate_event_sequences
    on offers.offer_id = duplicate_event_sequences.offer_id
    and offers.event_sequence = duplicate_event_sequences.event_sequence
order by
    offers.offer_id,
    offers.event_sequence,
    offers.ingested_at,
    offers.source_record_id
