with staged_requests as (

    select distinct
        request_id
    from
        {{ ref('stg_valuation_requests') }}
    where
        request_id is not null

)

, dimension_request_counts as (

    select
        request_id
        , count(*) as dimension_row_count
    from
        {{ ref('dim_valuations') }}
    group by
        request_id

)

select
    staged_requests.request_id
    , coalesce(dimension_request_counts.dimension_row_count, 0) as dimension_row_count
from
    staged_requests
left join
    dimension_request_counts
    on staged_requests.request_id = dimension_request_counts.request_id
where
    coalesce(dimension_request_counts.dimension_row_count, 0) != 1
