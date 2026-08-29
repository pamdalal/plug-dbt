select
    source.source_system,
    source.source_record_id,
    source.source_batch_id,
    source.ingested_at
from {{ ref('raw_vehicle_assessments') }} as source
left join {{ ref('stg_vehicle_assessments') }} as staging
    on source.source_system = staging.source_system
    and source.source_record_id = staging.source_record_id
where staging.source_record_id is null
