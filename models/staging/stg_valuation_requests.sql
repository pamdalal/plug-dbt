{{ config(
    materialized = 'incremental',
    incremental_strategy = 'append'
) }}

with source as (

    select
        source_record_id
        , source_system
        , source_batch_id
        , schema_version
        , synthetic_vin
        , request_id
        , source_updated_at
        , ingested_at
        , seller_id
        , submission_channel
        , market_region
        , odometer_value
        , odometer_unit
        , submitted_at
    from
        {{ ref('raw_valuation_requests') }}

    {% if is_incremental() %}
    where
        cast(ingested_at as timestamp_ntz) > (
            select
                coalesce(
                    max(ingested_at_ts)
                    , '1900-01-01'::timestamp_ntz
                )
            from
                {{ this }}
        )
    {% endif %}

)

, typed as (

    select
        source_record_id
        , source_system
        , source_batch_id
        , schema_version
        , synthetic_vin
        , request_id
        , source_updated_at
        , cast(source_updated_at as timestamp_ntz) as source_updated_at_ts
        , ingested_at
        , cast(ingested_at as timestamp_ntz) as ingested_at_ts
        , seller_id
        , submission_channel
        , market_region
        , odometer_value
        , cast(odometer_value as number(18, 2)) as odometer_value_num
        , odometer_unit
        , case
            when odometer_unit = 'mi'
                then cast(odometer_value as number(18, 3))
            when odometer_unit = 'km'
                then cast(odometer_value / 1.609344 as number(18, 3))
        end as odometer_miles
        , case
            when odometer_unit = 'km'
                then cast(odometer_value as number(18, 3))
            when odometer_unit = 'mi'
                then cast(odometer_value * 1.609344 as number(18, 3))
        end as odometer_kilometers
        , submitted_at
        , cast(submitted_at as timestamp_ntz) as submitted_at_ts
    from
        source

)

, final as (

    select
        source_record_id
        , source_system
        , source_batch_id
        , schema_version
        , synthetic_vin
        , request_id
        , source_updated_at
        , source_updated_at_ts
        , ingested_at
        , ingested_at_ts
        , seller_id
        , submission_channel
        , market_region
        , odometer_value
        , odometer_value_num
        , odometer_unit
        , odometer_miles
        , odometer_kilometers
        , submitted_at
        , submitted_at_ts
    from
        typed

)

select
    source_record_id
    , source_system
    , source_batch_id
    , schema_version
    , synthetic_vin
    , request_id
    , source_updated_at
    , source_updated_at_ts
    , ingested_at
    , ingested_at_ts
    , seller_id
    , submission_channel
    , market_region
    , odometer_value
    , odometer_value_num
    , odometer_unit
    , odometer_miles
    , odometer_kilometers
    , submitted_at
    , submitted_at_ts
from
    final
