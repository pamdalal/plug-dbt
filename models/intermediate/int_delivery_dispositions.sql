{{ config(materialized='view') }}

select
    delivery_sk,
    disposition,
    disposition_reason,
    request_id,
    source,
    survivor_delivery_sk
from {{ ref('int_valuation_request_dispositions') }}

union all

select
    delivery_sk,
    disposition,
    disposition_reason,
    request_id,
    source,
    survivor_delivery_sk
from {{ ref('int_vehicle_assessment_dispositions') }}

union all

select
    delivery_sk,
    disposition,
    disposition_reason,
    request_id,
    source,
    survivor_delivery_sk
from {{ ref('int_offer_event_dispositions') }}

union all

select
    delivery_sk,
    disposition,
    disposition_reason,
    request_id,
    source,
    survivor_delivery_sk
from {{ ref('int_marketplace_event_dispositions') }}
