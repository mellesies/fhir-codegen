# -*- coding: utf-8 -*-
from __future__ import print_function
from collections import OrderedDict
from datetime import datetime
import dateutil.parser
import inspect
import re
import logging
import pprint

import xml.etree.ElementTree as ET
import xml.dom.minidom


__all__ = [
    'inf',
    'PropertyCardinalityError',
    'PropertyTypeError',
    'PropertyDefinition',
    'Property',
    'PropertyList',
]

# Module global
inf = float('inf')

PRIMITIVE_TYPES = {
    # 'Element': 'Element',
    'markdown': 'str',
    'integer': 'int',
    'dateTime': 'FHIRdatetime',
    'unsignedInt': 'int',
    'code': 'str',
    'date': 'FHIRdate',
    'decimal': 'float',
    'uri': 'str',
    'id': 'str',
    'base64Binary': 'str',
    'time': 'FHIRtime',
    'oid': 'str',
    'positiveInt': 'int',
    'string': 'str',
    'boolean': 'bool',
    'uuid': 'str',
    'instant': 'FHIRdatetime',
}


# ------------------------------------------------------------------------------
# Exceptions & Errors
# ------------------------------------------------------------------------------
class PropertyCardinalityError(Exception):
    def __init__(self, method, description):
        message = "Cannot {} property '{}': cardinality [{}..{}]"
        message = message.format(method, description.name, description.cmin, description.cmax)
        super(PropertyCardinalityError, self).__init__(message)
class PropertyTypeError(Exception):
    def __init__(self, type_, description):
        message = "Expected '{}' but got '{}'".format(description.type, type_)
        super(PropertyTypeError, self).__init__(message)

# ------------------------------------------------------------------------------
# Property classes to declaratively define FHIR model.
# ------------------------------------------------------------------------------
class PropertyDefinition(object):
    
    def __init__(self, name, type_, cmin, cmax, repr_='element'):
        assert name.find(' ') < 0, "'name' should not contain spaces."
        
        cmin = int(cmin)
        if cmax == '*':
            cmax = inf
        else:
            cmax = int(cmax)
        
        self.name = name
        self.type = type_
        self.cmin = cmin
        self.cmax = cmax
        self.repr = repr_
    
    def __repr__(self):
        params = {
            'name': self.name,
            'type': self.type,
            'cmin': self.cmin,
            'cmax': self.cmax,
            'repr': self.repr,
        }
        return "PropertyDefinition('{name}', '{type}', '{cmin}', '{cmax}', '{repr}')".format(**params)

class PropertyMixin(object):
    def coerce_type(self, value):
        """Coerce/cast value to correspond to PropertyDefinition."""
        logger = logging.getLogger('PropertyMixin')
        import sys
        
        if value is None:
            return None
        
        if isinstance(self._definition.type, list):
            logger.warn('Not coercing properties with multiple types just yet')
            return value

        # If the following matches, we need to lazily evaluate the type
        if isinstance(self._definition.type, str):
            this = sys.modules[__name__]
            constructor = getattr(this, self._definition.type)
        else:
            constructor = self._definition.type
        
        # If the following matches, we don't need to do anything ... 
        if isinstance(value, Element) and (value._url == constructor._url):
            return value
        
        # If we're still here, try to coerce/cast ..
        try:
            return constructor(value)
        except:
            print('')
            print(constructor, self._definition)
            raise PropertyTypeError(value.__class__.__name__, self._definition)
# PropertyMixin
        
class Property(PropertyMixin):
    _cls_counter = 0
    
    @classmethod
    def __get_creation_counter(cls):
        cls._cls_counter += 1
        return cls._cls_counter
    
    def __init__(self, definition):
        """Create new Property instance.
        
        :param PropertyDefinition definition: Description of the property.
        """
        self._creation_order = self.__get_creation_counter()
        self._definition = definition
    
    def __get__(self, instance, owner):
        if instance is None:
            # instance attribute accessed on class, return self
            return self
        
        # instance attribute accessed on instance, return value
        # print(self._definition.name)
        value = getattr(instance, '__' + self._definition.name, None)
        
        if (self._definition.cmax > 1) and (value is None):
            value = PropertyList(self._definition)
            setattr(instance, '__' + self._definition.name, value)
        
        return value
    
    def __set__(self, instance, value):
        if self._definition.cmax > 1: 
            raise PropertyCardinalityError('set', self._definition.name)

        setattr(instance, '__' + self._definition.name, self.coerce_type(value))

    
    def __repr__(self):
        s = 'Property({})'.format(self._definition)
        return s
# class Property

class PropertyList(list, PropertyMixin):
    """PropertyLists are used by Propertys when cardinality > 1."""
    
    def __init__(self, definition, *args, **kwargs):
        """Create a new PropertyList instance.
        Note that minimum cardinality is not enforced when calling 'append'.
         
        :param PropertyDefinition definition: Description of the property.
        """
        super(PropertyList, self).__init__(*args, **kwargs)
        self._definition = definition

    def insert(self, i, x):
        """Insert a value into the list at position i."""
        # This raises a PropertyTypeError if x has an incorrect value.
        x = self.coerce_type(x)
        
        if len(self) >= self._definition.cmax:
            raise PropertyCardinalityError('insert', self._definition)
            
        super(PropertyList, self).insert(i, x)
         
    def append(self, x):
        """Append a value to the list."""
        # This raises a PropertyTypeError if x has an incorrect value.
        x = self.coerce_type(x)
        
        if len(self) >= self._definition.cmax:
            raise PropertyCardinalityError('append', self._definition)
            
        super(PropertyList, self).append(x)
# class PropertyList   


# ------------------------------------------------------------------------------
# Base classes
# ------------------------------------------------------------------------------
class FHIRBase(object):
    """Base class for all FHIR resources and elements."""
    
    def __init__(self, value=None):
        """Create a new instance."""
        self.value = value
    
    def _getProperties(self):
        """Return a list (ordered) of instance attribute names that are of type 
        'Property'
        """
        properties = []
        for attr in dir(type(self)):
            a = getattr(type(self), attr)
            if isinstance(a, Property):
                properties.append(a)
                
        properties.sort(key=lambda i: i._creation_order)
        properties = [p._definition.name for p in properties]
        
        return properties
    
    def serialize(self, format_='xml'):
        if format_ in ['xml', 'json']:
            format_ = format_.upper()
            func = getattr(self, 'to' + format_)
            return func()
    
    def toJSON(self, parent=None, path=None):
        """
        {
          "resourceType": "Resource",
          "id": "...",
          "text": "...",
        }
        """
        if parent is None:            
            # This will (should) only happen if I'm a Resource. Resources should
            # create the root element and iterate over their attribues.
            tag = self.__class__.__name__
            parent = dict()
        
        # Only the root element needs to generate the actual JSON.
        if len(path) == 1:
            return json.dumps(parent, indent=4)
    
    def toXML(self, parent=None, path=None):
        """
        <parent value='value'>
          <id value='value'/>
          <extension url='url'>
            <stringValue value='value'/>
          </extension>
        </parent>
        """
        if parent is None:            
            # This will (should) only happen if I'm a Resource. Resources should
            # create the root element and iterate over their attribues.
            tag = self.__class__.__name__
            parent = ET.Element(tag)
            parent.set('xmlns', 'http://hl7.org/fhir')
            path = [tag, ]        
        
        # Iterate over *my* attributes.
        for attr in self._getProperties():
            value = getattr(self, attr)
            desc = getattr(type(self), attr)._definition
            path_str = '.'.join(path + [attr, ])
            
            
            # if isinstance(value, BaseType):
            #     print('{} ({})'.format(path_str, value.__class__.__name__))
            # else:
            #     print('{}: {} ({})'.format(path_str, value, type(value)))
            
            if value is not None:
                if desc.repr == 'xmlAttr':
                    parent.set(attr, str(value))
            
                elif isinstance(value, PropertyList):
                    for p in value:
                        p.toXML(ET.SubElement(parent, attr), path + [attr, ])
                        
                elif isinstance(value, FHIRBase):
                    value.toXML(ET.SubElement(parent, attr), path + [attr, ])
        
        
        # Only the root element needs to generate the actual XML.
        if len(path) == 1:
            x = xml.dom.minidom.parseString(ET.tostring(parent)) 
            return x.toprettyxml(indent='  ')
# class FHIRBase 
            
class Element(FHIRBase):
    """Base definition for all elements in a resource."""
    _timestamp = {{timestamp}}
    
    _url = 'http://hl7.org/fhir/StructureDefinition/Element'
    
    id = Property(PropertyDefinition('id', 'id', '0', '1'))
    extension = Property(PropertyDefinition('extension', 'Extension', '0', '*'))
# class Element

class Extension(Element):
    """Optional Extensions Element - found in all resources."""
    _url = 'http://hl7.org/fhir/StructureDefinition/Extension'
    
    url = Property(PropertyDefinition('url', 'uri', '1', '1', 'xmlAttr'))
    value = Property(PropertyDefinition(
        'value', 
        ['boolean', 'integer', 'decimal', 'base64Binary', 'instant', 'string', 
            'uri', 'date', 'dateTime', 'time', 'code', 'oid', 'id', 
            'unsignedInt', 'positiveInt', 'markdown', 'Annotation', 'Attachment', 
            'Identifier', 'CodeableConcept', 'Coding', 'Quantity', 'Range', 
            'Period', 'Ratio', 'SampledData', 'Signature', 'HumanName', 'Address', 
            'ContactPoint', 'Timing', 'Reference', 'Meta'], 
        '0', 
        '1')
    )
# class Extension

class BaseType(Element):
    """Base for basic/simple types."""
        
    def __repr__(self):
        """repr(x) <==> x.__repr__()"""
        return repr(self.value)
# class BaseType

# ------------------------------------------------------------------------------
# date/time types
# ------------------------------------------------------------------------------

# FHIR types
# ----------
# date: {xs:date, xs:gYearMonth, xs:gYear}
#  - *no* timezone
#  - regex: -?[0-9]{4}(-(0[1-9]|1[0-2])(-(0[0-9]|[1-2][0-9]|3[0-1]))?)?

# time: 
#  - {xs:time}, *no* timezone
#  - regex: ([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]+)?
# 
# dateTime: 
#  - {xs:dateTime, xs:date, xs:gYearMonth, xs:gYear}
#  - timezone *conditional* on population of hours & minutes
#  - regex: -?[0-9]{4}(-(0[1-9]|1[0-2])(-(0[0-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]+)?(Z|(\+|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00)))?)?)?
# 
# instant: {xs:dateTime}
#  - timezone *required*
#  - regex: <none>?
class dateTimeBase(BaseType):
    """Base class for date/time classes.
    
    The currently available modules are not capable of storing None values for
    months, days, hours, etc. As a side effect, parsing a string with only a 
    year e.g. strptime('2015', '%Y') automatically sets the month to january!?
    """
    _regex = None
    
    def __init__(self, value):
        if self._regex and re.match(self._regex, value):
            # The logic below would ideally be implemented by the subclass in
            # question, but this makes generating the subclasses much easier.
            if isinstance(self, dateTime) or isinstance(self, instant):
                p = dateutil.parser.parse(value)
                
                if isinstance(self, dateTime) and (p.hour or p.minute or p.second) and (p.tzinfo is None):
                    args = [value, self.__class__.__name__]
                    raise ValueError('"{}" is not a valid {}'.format(*args))
                
                elif isinstance(self, instant) and (p.tzinfo is None):
                    args = [value, self.__class__.__name__]
                    raise ValueError('"{}" is not a valid {}'.format(*args))
            
            self._value = value
        else:
            args = [value, self.__class__.__name__]
            raise ValueError('"{}" is not a valid {}'.format(*args))
            
    def __repr__(self):
        return repr(self._value)
    
    def __str__(self):
        return self._value
        


# Import basic types into module/package 'fhir'
{% for t in basic_types %}
from fhir._{{t.classname.lower()}} import {{t.classname}}
{% endfor %}

# Import complex types and resources into module/package 'fhir'
{% for t in processed_items %}
from fhir.{{t.lower()}} import {{t}}
{% endfor %}

# __all__ = [{% for t in types %}'{{t.classname}}', {% endfor %}]