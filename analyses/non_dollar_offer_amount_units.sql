select
    source_record_id,
    source_event_id,
    offer_id,
    request_id,
    event_type,
    event_sequence,
    offer_version,
    offer_amount,
    offer_amount_unit,
    currency_code,
    source_batch_id,
    source_updated_at,
    ingested_at
from {{ ref('raw_offer_events') }}
where offer_amount_unit <> 'dollars'
order by
    ingested_at,
    source_record_id
