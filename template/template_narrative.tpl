{% extends "template_item.tpl" %}

{% block properties %}
    {% for a in r.attributes.values() %}
    {% if a.name == 'div' %}
    {{a.name}} = Property('{{a.name}}', {{a.type}}, '{{a.min}}', '{{a.max}}', 'text')
    {% else %}
    {{a.name}} = Property('{{a.name}}', {{a.type}}, '{{a.min}}', '{{a.max}}')
    {% endif %}
    {% endfor %}
{% endblock properties %}
