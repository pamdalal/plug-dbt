{% test required_when(model, column_name, condition) %}

select
    *
from {{ model }}
where {{ condition }}
    and {{ column_name }} is null

{% endtest %}
