select
    source.source_record_id,
    source.source_batch_id,
    source.ingested_at
from {{ ref('raw_valuation_requests') }} as source
left join {{ ref('stg_valuation_requests') }} as staging
    on source.source_record_id = staging.source_record_id
where staging.source_record_id is null
