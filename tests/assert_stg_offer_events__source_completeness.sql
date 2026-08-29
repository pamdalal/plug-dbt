with source_deliveries as (

    select
        source_record_id
        , source_batch_id
        , ingested_at
    from
        {{ ref('raw_offer_events') }}

)

, staged_deliveries as (

    select
        source_record_id
    from
        {{ ref('stg_offer_events') }}

)

select
    source_deliveries.source_record_id
    , source_deliveries.source_batch_id
    , source_deliveries.ingested_at
from
    source_deliveries
left join
    staged_deliveries
    on source_deliveries.source_record_id = staged_deliveries.source_record_id
where
    staged_deliveries.source_record_id is null
