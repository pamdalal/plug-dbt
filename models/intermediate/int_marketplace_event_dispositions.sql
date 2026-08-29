{{ config(materialized='view') }}

with evaluated as (

    select
        *,
        (
            source_record_id is not null
            and source_system = 'dealer_marketplace'
            and source_batch_id is not null
            and schema_version is not null
            and synthetic_vin is not null
            and request_id is not null
            and source_updated_at_ts is not null
            and ingested_at_ts is not null
            and source_updated_at_ts <= ingested_at_ts
            and ingested_at_ts < to_timestamp_tz('2026-07-31T00:00:00Z')
        ) as physical_envelope_valid,
        (
            schema_version = '1.0'
            and source_event_id is not null
            and offer_id is not null
            and auction_id is not null
            and event_sequence_numeric > 0
            and event_type in (
                'listing_created',
                'bid_submitted',
                'auction_closed',
                'sale_confirmed',
                'transaction_completed',
                'transaction_cancelled'
            )
            and event_at_ts is not null
            and event_at_ts <= source_updated_at_ts
            and event_at_ts < to_timestamp_tz('2026-07-31T00:00:00Z')
            and (
                (
                    event_type = 'listing_created'
                    and event_sequence_numeric = 1
                    and scheduled_close_at_ts is not null
                    and event_at_ts <= scheduled_close_at_ts
                    and bid_id is null
                    and dealer_id is null
                    and transaction_id is null
                    and event_amount_numeric > 0
                    and event_amount_unit = 'usd'
                    and currency_code = 'USD'
                    and amount_role = 'reserve'
                    and auction_result_code is null
                )
                or (
                    event_type = 'bid_submitted'
                    and scheduled_close_at is null
                    and bid_id is not null
                    and dealer_id is not null
                    and transaction_id is null
                    and event_amount_numeric > 0
                    and event_amount_unit = 'usd'
                    and currency_code = 'USD'
                    and amount_role = 'bid'
                    and auction_result_code is null
                )
                or (
                    event_type = 'auction_closed'
                    and scheduled_close_at is null
                    and transaction_id is null
                    and event_amount is null
                    and event_amount_unit is null
                    and currency_code is null
                    and amount_role is null
                    and (
                        (
                            auction_result_code = 'awarded'
                            and bid_id is not null
                            and dealer_id is not null
                        )
                        or (
                            auction_result_code in (
                                'no_bid',
                                'reserve_not_met'
                            )
                            and bid_id is null
                            and dealer_id is null
                        )
                    )
                )
                or (
                    event_type = 'sale_confirmed'
                    and scheduled_close_at is null
                    and bid_id is not null
                    and dealer_id is not null
                    and transaction_id is not null
                    and event_amount_numeric > 0
                    and event_amount_unit = 'usd'
                    and currency_code = 'USD'
                    and amount_role = 'confirmed_dealer_price'
                    and auction_result_code is null
                )
                or (
                    event_type in (
                        'transaction_completed',
                        'transaction_cancelled'
                    )
                    and scheduled_close_at is null
                    and bid_id is null
                    and dealer_id is null
                    and transaction_id is not null
                    and event_amount is null
                    and event_amount_unit is null
                    and currency_code is null
                    and amount_role is null
                    and auction_result_code is null
                )
            )
        ) as supported_row_valid,
        md5(
            to_json(
                array_construct(
                    schema_version,
                    synthetic_vin,
                    request_id,
                    date_part(epoch_second, source_updated_at_ts),
                    source_event_id,
                    offer_id,
                    auction_id,
                    event_sequence,
                    event_type,
                    date_part(epoch_second, event_at_ts),
                    date_part(epoch_second, scheduled_close_at_ts),
                    bid_id,
                    dealer_id,
                    transaction_id,
                    event_amount,
                    event_amount_unit,
                    currency_code,
                    amount_role,
                    auction_result_code
                )
            )
        ) as replay_payload_hash
    from {{ ref('stg_marketplace_events') }}

),

replay_candidates as (

    select *
    from evaluated
    where physical_envelope_valid
        and supported_row_valid

),

replay_groups as (

    select
        auction_id,
        event_sequence,
        source_system,
        count(distinct replay_payload_hash) as replay_payload_count
    from replay_candidates
    group by
        auction_id,
        event_sequence,
        source_system

),

ranked as (

    select
        replay_candidates.delivery_sk,
        replay_groups.replay_payload_count,
        row_number() over (
            partition by
                replay_candidates.source_system,
                replay_candidates.auction_id,
                replay_candidates.event_sequence
            order by
                replay_candidates.ingested_at_ts,
                replay_candidates.source_record_id
        ) as replay_delivery_rank,
        first_value(replay_candidates.delivery_sk) over (
            partition by
                replay_candidates.source_system,
                replay_candidates.auction_id,
                replay_candidates.event_sequence
            order by
                replay_candidates.ingested_at_ts,
                replay_candidates.source_record_id
        ) as survivor_delivery_sk
    from replay_candidates
    inner join replay_groups
        on replay_candidates.source_system = replay_groups.source_system
        and replay_candidates.auction_id = replay_groups.auction_id
        and replay_candidates.event_sequence = replay_groups.event_sequence

),

base_dispositions as (

    select
        evaluated.*,
        case
            when not evaluated.physical_envelope_valid then 'quarantined'
            when evaluated.schema_version <> '1.0' then 'quarantined'
            when not coalesce(evaluated.supported_row_valid, false)
                then 'quarantined'
            when ranked.replay_payload_count > 1 then 'quarantined'
            when ranked.replay_delivery_rank = 1 then 'accepted'
            else 'duplicate'
        end as base_disposition,
        case
            when not evaluated.physical_envelope_valid then 'schema_validation_error'
            when evaluated.schema_version <> '1.0' then 'unsupported_schema_version'
            when not coalesce(evaluated.supported_row_valid, false)
                then 'schema_validation_error'
            when ranked.replay_payload_count > 1 then 'immutable_key_conflict'
            when ranked.replay_delivery_rank > 1 then 'exact_replay'
        end as base_disposition_reason,
        case
            when ranked.replay_payload_count = 1
                and ranked.replay_delivery_rank > 1
                then ranked.survivor_delivery_sk
        end as survivor_delivery_sk
    from evaluated
    left join ranked
        on evaluated.delivery_sk = ranked.delivery_sk

),

canonical_offer_keys as (

    select distinct
        offer_id,
        request_id
    from {{ ref('int_canonical_offer_events') }}

),

relationship_evaluated as (

    select
        base_dispositions.*,
        case
            when base_dispositions.base_disposition <> 'accepted' then null
            when requests.request_id is null then 'orphaned_request'
            when base_dispositions.synthetic_vin <> requests.synthetic_vin
                then 'identity_mismatch'
            when canonical_offer_keys.offer_id is null then 'orphaned_offer'
        end as relationship_reason
    from base_dispositions
    left join {{ ref('int_canonical_valuation_requests') }} as requests
        on base_dispositions.request_id = requests.request_id
    left join canonical_offer_keys
        on base_dispositions.request_id = canonical_offer_keys.request_id
        and base_dispositions.offer_id = canonical_offer_keys.offer_id

),

eligible_events as (

    select *
    from relationship_evaluated
    where base_disposition = 'accepted'
        and relationship_reason is null

),

auction_closes as (

    select
        auction_id,
        count_if(event_type = 'auction_closed') as close_count,
        count_if(
            event_type = 'auction_closed'
            and auction_result_code = 'awarded'
        ) as awarded_close_count,
        max(
            case
                when event_type = 'auction_closed'
                    and auction_result_code = 'awarded'
                    then bid_id
            end
        ) as awarded_bid_id,
        max(
            case
                when event_type = 'auction_closed'
                    and auction_result_code = 'awarded'
                    then dealer_id
            end
        ) as awarded_dealer_id,
        max(
            case
                when event_type = 'auction_closed'
                    and auction_result_code = 'awarded'
                    then event_at_ts
            end
        ) as awarded_close_at_ts
    from eligible_events
    group by auction_id

)

select
    relationship_evaluated.delivery_sk,
    relationship_evaluated.request_id,
    relationship_evaluated.survivor_delivery_sk,
    'raw_marketplace_events' as source,
    case
        when relationship_evaluated.base_disposition <> 'accepted'
            then relationship_evaluated.base_disposition
        when relationship_evaluated.relationship_reason is not null
            then 'quarantined'
        when relationship_evaluated.event_type = 'sale_confirmed'
            and (
                coalesce(auction_closes.close_count, 0) <> 1
                or coalesce(auction_closes.awarded_close_count, 0) <> 1
                or relationship_evaluated.bid_id <> auction_closes.awarded_bid_id
                or relationship_evaluated.dealer_id
                    <> auction_closes.awarded_dealer_id
                or relationship_evaluated.event_at_ts
                    <= auction_closes.awarded_close_at_ts
            )
            then 'quarantined'
        else 'accepted'
    end as disposition,
    case
        when relationship_evaluated.base_disposition <> 'accepted'
            then relationship_evaluated.base_disposition_reason
        when relationship_evaluated.relationship_reason is not null
            then relationship_evaluated.relationship_reason
        when relationship_evaluated.event_type = 'sale_confirmed'
            and (
                coalesce(auction_closes.close_count, 0) <> 1
                or coalesce(auction_closes.awarded_close_count, 0) <> 1
                or relationship_evaluated.bid_id <> auction_closes.awarded_bid_id
                or relationship_evaluated.dealer_id
                    <> auction_closes.awarded_dealer_id
                or relationship_evaluated.event_at_ts
                    <= auction_closes.awarded_close_at_ts
            )
            then 'invalid_marketplace_transition'
    end as disposition_reason
from relationship_evaluated
left join auction_closes
    on relationship_evaluated.auction_id = auction_closes.auction_id
