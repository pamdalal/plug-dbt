{{ config(materialized='view') }}

select
    staging.amount_role,
    staging.auction_id,
    staging.auction_result_code,
    staging.bid_id,
    staging.currency_code,
    staging.dealer_id,
    staging.delivery_sk,
    staging.event_amount,
    staging.event_amount_numeric,
    staging.event_amount_usd,
    staging.event_amount_usd_cents,
    staging.event_amount_unit,
    staging.event_amount_unit_normalized,
    staging.event_at,
    staging.event_at_ts,
    staging.event_sequence,
    staging.event_sequence_numeric,
    staging.event_type,
    staging.has_non_z_timestamp_representation,
    staging.ingested_at,
    staging.ingested_at_ts,
    staging.offer_id,
    staging.request_id,
    staging.scheduled_close_at,
    staging.scheduled_close_at_ts,
    staging.schema_version,
    staging.source_batch_id,
    staging.source_event_id,
    staging.source_record_id,
    staging.source_system,
    staging.source_updated_at,
    staging.source_updated_at_ts,
    staging.synthetic_vin,
    staging.transaction_id
from {{ ref('stg_marketplace_events') }} as staging
inner join {{ ref('int_marketplace_event_dispositions') }} as dispositions
    on staging.delivery_sk = dispositions.delivery_sk
where dispositions.disposition = 'accepted'
