{% extends "template_item.tpl" %}

{% block import %}
{{super()}}
import xml.etree.ElementTree as ET
{% endblock import %}


{% block class %}
{{super()}}
    
    def toXML(self, parent=None, path=None):
        """Return an XML representation of this object."""
        tag = self.__class__.__name__
        
        if parent is None:
            parent = ET.Element(tag)
            parent.set('xmlns', 'http://hl7.org/fhir')
            path = [tag, ]
        else:
            # Resources *always* render their type tag (e.g. '<Patient>')
            parent = ET.SubElement(parent, tag)
        
        return super().toXML(parent, path)
{% endblock class %}
