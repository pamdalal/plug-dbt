{% test null_when(model, column_name, condition) %}

select
    *
from {{ model }}
where {{ condition }}
    and {{ column_name }} is not null

{% endtest %}
