select
    duplicates.source,
    duplicates.delivery_sk,
    duplicates.disposition,
    duplicates.disposition_reason,
    duplicates.survivor_delivery_sk,
    survivors.disposition as survivor_disposition
from {{ ref('int_delivery_dispositions') }} as duplicates
left join {{ ref('int_delivery_dispositions') }} as survivors
    on duplicates.source = survivors.source
    and duplicates.survivor_delivery_sk = survivors.delivery_sk
where (
    duplicates.disposition = 'duplicate'
    and (
        duplicates.disposition_reason <> 'exact_replay'
        or duplicates.survivor_delivery_sk is null
        or survivors.disposition <> 'accepted'
    )
)
or (
    duplicates.disposition <> 'duplicate'
    and duplicates.survivor_delivery_sk is not null
)
