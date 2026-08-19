select
    requests.source_record_id,
    requests.request_id,
    requests.submitter_type,
    requests.submitter_account_id,
    requests.channel,
    requests.vin_like,
    requests.odometer_value,
    requests.odometer_unit,
    requests.postal_code,
    requests.submitted_at,
    requests.source_batch_id,
    requests.source_updated_at,
    requests.ingested_at
from {{ ref('raw_valuation_requests') }} as requests
left join {{ ref('raw_offer_events') }} as offers
    on requests.request_id = offers.request_id
where offers.request_id is null
order by
    requests.submitted_at,
    requests.source_record_id
