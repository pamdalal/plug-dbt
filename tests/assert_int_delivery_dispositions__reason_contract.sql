select
    source,
    delivery_sk,
    disposition,
    disposition_reason,
    survivor_delivery_sk
from {{ ref('int_delivery_dispositions') }}
where (disposition = 'accepted' and disposition_reason is not null)
    or (disposition = 'duplicate' and disposition_reason <> 'exact_replay')
    or (disposition = 'quarantined' and disposition_reason is null)
