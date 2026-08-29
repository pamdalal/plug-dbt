with source_deliveries as (

    select
        {{ dbt_utils.generate_surrogate_key([
            '<verified_delivery_key_column>'
        ]) }} as <delivery_sk>
        , <ingestion_watermark>
    from
        <source_or_ref_expression>

)

, staged_deliveries as (

    select
        <delivery_sk>
    from
        {{ ref('<staging_model_name>') }}

)

select
    source_deliveries.<delivery_sk>
    , source_deliveries.<ingestion_watermark>
from
    source_deliveries
left join
    staged_deliveries
    on source_deliveries.<delivery_sk> = staged_deliveries.<delivery_sk>
where
    staged_deliveries.<delivery_sk> is null
