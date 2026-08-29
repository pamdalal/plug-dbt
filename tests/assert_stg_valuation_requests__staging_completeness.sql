select
    staging.source_system,
    staging.source_record_id,
    staging.source_batch_id,
    staging.ingested_at
from {{ ref('stg_valuation_requests') }} as staging
left join {{ ref('raw_valuation_requests') }} as source
    on staging.source_system = source.source_system
    and staging.source_record_id = source.source_record_id
where source.source_record_id is null
