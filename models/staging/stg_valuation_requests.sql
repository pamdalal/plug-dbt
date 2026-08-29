{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='fail'
    )
}}

with source as (

    select
        ingested_at,
        market_region,
        odometer_unit,
        odometer_value,
        request_id,
        schema_version,
        seller_id,
        source_batch_id,
        source_record_id,
        source_system,
        source_updated_at,
        submission_channel,
        submitted_at,
        synthetic_vin,
        to_timestamp_tz(ingested_at) as ingested_at_ts,
        try_to_decimal(odometer_value, 38, 0) as odometer_value_numeric,
        try_to_timestamp_tz(source_updated_at) as source_updated_at_ts,
        try_to_timestamp_tz(submitted_at) as submitted_at_ts
    from {{ ref('raw_valuation_requests') }}

    {% if is_incremental() %}
        where (
            (select max(ingested_at_ts) from {{ this }}) is null
            or to_timestamp_tz(ingested_at)
                > (select max(ingested_at_ts) from {{ this }})
        )
    {% endif %}

)

select
    ingested_at,
    ingested_at_ts,
    market_region,
    odometer_unit,
    odometer_value,
    odometer_value_numeric,
    request_id,
    schema_version,
    seller_id,
    source_batch_id,
    source_record_id,
    source_system,
    source_updated_at,
    source_updated_at_ts,
    submission_channel,
    submitted_at,
    submitted_at_ts,
    synthetic_vin,
    md5(
        to_json(
            array_construct(
                'raw_valuation_requests',
                source_system,
                source_record_id
            )
        )
    ) as delivery_sk,
    (
        not regexp_like(ingested_at, 'Z$')
        or not regexp_like(source_updated_at, 'Z$')
        or not regexp_like(submitted_at, 'Z$')
    ) as has_non_z_timestamp_representation,
    cast(
        case
            when odometer_unit = 'km' then odometer_value_numeric
            when odometer_unit = 'mi' then odometer_value_numeric * 1.609344
        end
        as number(38, 6)
    ) as odometer_kilometers,
    cast(
        case
            when odometer_unit = 'mi' then odometer_value_numeric
            when odometer_unit = 'km' then odometer_value_numeric / 1.609344
        end
        as number(38, 6)
    ) as odometer_miles,
    odometer_unit = 'km' as odometer_unit_normalized
from source
