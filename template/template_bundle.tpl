{% extends "template_item.tpl" %}

{% block docstring %}
{{super()}}
    Implements iteration over Bundle.entry.resource.
{% endblock docstring %}

{% block properties %}
{{super()}}

    # FIXME: implement logic for following <link> tags
    def __iter__(self):
        return iter([entry.resource for entry in self.entry])
    
    
    def __len__(self):
        return len(self.entry)
{% endblock properties %}
