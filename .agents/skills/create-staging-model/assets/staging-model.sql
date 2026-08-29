{{-
    config(
        materialized = 'incremental'
    )
-}}

with source as (

    select
        <explicit_source_column>
        , <ingestion_watermark>
    from
        <source_or_ref_expression>
    where 1=1

    {% if is_incremental() %}
        and <ingestion_watermark> > (
            select max(<output_watermark>)
            from {{ this }}
        )
    {% endif %}

)

, renamed as (

    select
        <renamed_and_typed_column>
        , <ingestion_watermark> as <output_watermark>
    from
        source

)

, final as (

    select
        {{ dbt_utils.generate_surrogate_key([
            '<verified_delivery_key_column>'
        ]) }} as <delivery_sk>
        , <explicit_output_column>
        , <output_watermark>
    from
        renamed

)

select
    <delivery_sk>
    , <explicit_output_column>
    , <output_watermark>
from
    final
