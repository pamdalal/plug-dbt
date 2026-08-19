with normalized_requests as (

    select
        source_record_id,
        request_id,
        trim(upper(vin_like)) as normalized_vin_like,
        vin_like,
        submitter_type,
        submitter_account_id,
        channel,
        submitted_at,
        source_batch_id,
        source_updated_at,
        ingested_at
    from {{ ref('raw_valuation_requests') }}

),

colliding_vin_like_values as (

    select
        normalized_vin_like
    from normalized_requests
    group by normalized_vin_like
    having count(*) > 1

)

select
    requests.source_record_id,
    requests.request_id,
    requests.normalized_vin_like,
    requests.vin_like,
    requests.submitter_type,
    requests.submitter_account_id,
    requests.channel,
    requests.submitted_at,
    requests.source_batch_id,
    requests.source_updated_at,
    requests.ingested_at
from normalized_requests as requests
inner join colliding_vin_like_values
    on requests.normalized_vin_like = colliding_vin_like_values.normalized_vin_like
order by
    requests.normalized_vin_like,
    requests.submitted_at,
    requests.source_record_id
