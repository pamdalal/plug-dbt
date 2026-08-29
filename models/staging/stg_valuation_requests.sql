{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='append_new_columns'
    )
}}

with source as (

    select *
    from {{ ref('raw_valuation_requests') }}

    {% if is_incremental() %}
        where ingested_at > (select max(ingested_at) from {{ this }})
    {% endif %}

),

normalized as (

    select
        source_record_id,
        request_id,
        source_system,
        source_batch_id,
        schema_version,
        submitter_type,
        submitter_account_id,
        channel,
        vin_like,
        odometer_value,
        odometer_unit,
        postal_code,
        contact_name,
        contact_email,
        contact_phone,
        submitted_at,
        source_updated_at,
        ingested_at,
        md5(
            to_json(
                array_construct(
                    'valuation_request',
                    source_system,
                    source_record_id
                )
            )
        ) as valuation_request_sk
    from source

)

select
    valuation_request_sk,
    source_record_id,
    request_id,
    source_system,
    source_batch_id,
    schema_version,
    submitter_type,
    submitter_account_id,
    channel,
    vin_like,
    odometer_value,
    odometer_unit,
    postal_code,
    contact_name,
    contact_email,
    contact_phone,
    submitted_at,
    source_updated_at,
    ingested_at
from normalized
