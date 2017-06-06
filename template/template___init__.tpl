# -*- coding: utf-8 -*-
"""FHIR Resources & Elements in Python."""
from __future__ import print_function
import sys
import packaging.version
from collections import OrderedDict
from datetime import datetime
import dateutil.parser
import inspect
import re
import logging
import pprint
import html

import xml.etree.ElementTree as ET
import xml.dom.minidom
import json

__author__ = "Melle Sieswerda"
__copyright__  = "Copyright 2017, Melle Sieswerda"
__license__ = "GPL"
__version__ = "0.8"

__all__ = [
    'inf',
    'PropertyCardinalityError',
    'PropertyTypeError',
    'PropertyDefinition',
    'Property',
    'PropertyList',
    {% for t in basic_types %}
    '{{t.classname}}',
    {% endfor %}
    {% for t in processed_items if not t == 'Resource' %}
    '{{t}}',
    {% endfor %}
]

# Module global
FHIR_STU3 = packaging.version.parse('3.0.1')
FHIR_DSTU2 = packaging.version.parse('1.0.2')
VERSION = packaging.version.parse('{{version}}')

inf = float('inf')

PRIMITIVE_TYPES = OrderedDict([
    # ('Element', 'Element'),
    ('markdown', 'str'),
    ('integer', 'int'),
    ('dateTime', 'dateTimeBase'),
    ('unsignedInt', 'int'),
    ('code', 'str'),
    ('date', 'dateTimeBase'),
    ('decimal', 'float'),
    ('uri', 'str'),
    ('id', 'str'),
    ('base64Binary', 'str'),
    ('time', 'dateTimeBase'),
    ('oid', 'str'),
    ('positiveInt', 'int'),
    ('string', 'str'),
    ('boolean', 'bool'),
    ('uuid', 'str'),
    ('instant', 'dateTimeBase'),
    ('xhtml', 'str'),
])

def upper_first_letter(attr):
    return attr[0].upper() + attr[1:]

def lower_first_letter(attr):
    return attr[0].lower() + attr[1:]

def split_namespace(element_or_tag):
    if isinstance(element_or_tag, ET.Element):
        tag = element_or_tag.tag
    else:
        tag = element_or_tag
    
    m = re.match('\{(.*)\}', tag)
    ns_with_accolades = m.group(0) if m else ''
    ns_without_accolades = m.group(1) if m else ''
    return ns_without_accolades, tag.replace(ns_with_accolades, '')

def get_type(type_):
    if isinstance(type_, str):
        return getattr(sys.modules[__name__], type_)
    elif issubclass(type_, FHIRBase):
        return type_

# ------------------------------------------------------------------------------
# Exceptions & Errors
# ------------------------------------------------------------------------------
class PropertyCardinalityError(Exception):
    def __init__(self, method, description):
        message = "Cannot {} property '{}': cardinality [{}..{}]"
        message = message.format(method, description.name, description.cmin, description.cmax)
        super(PropertyCardinalityError, self).__init__(message)
# class PropertyCardinalityError

class PropertyTypeError(Exception):
    def __init__(self, type_, description):
        msg = "Expected '{}' but got '{}' for '{}'".format(description.type, type_, description.name)
        super(PropertyTypeError, self).__init__(msg)
# class PropertyTypeError

class InvalidAttributeError(Exception):
    def __init__(self, resource_or_element, attr):
        msg = "The attribute '{}' is not a valid property for '{}'.".format(attr, resource_or_element)
        super(InvalidAttributeError, self).__init__(msg)

# ------------------------------------------------------------------------------
# Property classes to declaratively define FHIR model.
# ------------------------------------------------------------------------------
class PropertyDefinition(object):
    """Used by Property to hold the definition of an attribute of a Resource or Element."""
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
# class PropertyDefinition

class PropertyMixin(object):
    """
        Provides methods to coerce (~cast) native types (str, int) to FHIR types 
        (string, decimal). Used by Property and PropertyList.
    """
    def coerce_multi_type(self, value, types):
        """
            Coerce 'value' to a type in 'types'.

            For properties that support more than one type, first check if the
            provided value actually is of one of these types. If not, try to cast
            to a supported value by simply trying each supported type.
            
            Example of a property that supports more than one type:
                multi = Property(PropertyDefinition('multi', ['boolean', 'dateTime'], '0', '1'))
        """
        if isinstance(value, Element):
            if type(value).__name__ not in types:
                raise PropertyTypeError(type(value).__name__, self.definition)
        
            return value
        
        # Ok, so value is not (yet) a fhir type. Try to find a supported type.
        for type_ in self.definition.type:
            constructor = getattr(sys.modules[__name__], type_)

            try:
                value = constructor(value)
            except PropertyTypeError as e:
                # print("Apparently '{}' is not a '{}'".format(value, type_))
                pass
            else:
                return value
        
        # FIXME: change to more meaningful exception!
        raise Exception("Could not find a proper type for value '{}' in {}".format(value, self.definition.type))
    # def coerce_multi_type
    
    def coerce_type(self, value):
        """Coerce (~cast) value to correspond to PropertyDefinition."""
        logger = logging.getLogger('PropertyMixin')
        type_ = self.definition.type
        
        if value is None and not issubclass(type_, Element):
            return None

        # PropertyDefinition.type might defined as string --> lazily evaluate.
        # FIXME: this will probably fail for references!
        if isinstance(type_, str):
            type_ = get_type(type_)

        # Check for multi typed properties first. isinstance will complain if
        # it receives a list of strings as 2nd argument.
        if isinstance(type_, list):
            return self.coerce_multi_type(value, type_)
        
        # If value already has the correct type, we don't need to do anything.
        if isinstance(value, FHIRBase) and isinstance(value, type_):
            return value

        # If we're still here, try to coerce/cast.
        # This has a side effect: any current value will be replaced by a new instance!
        try:
            # print('casting value {} to {}'.format(value, type_))
            return type_(value)
        except Exception as e:
            raise PropertyTypeError(value.__class__.__name__, self.definition)
# class PropertyMixin
        
class Property(PropertyMixin):
    """Property of a Resource or Element.

        This class defines logic to ensure that Resource/Element (and 
        subclasses) behave much like regular Python objects, while providing
        functionality specific to the FHIR standard.
    """
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
        self.definition = definition
        self.name = definition.name
    
    def __get__(self, instance, owner):
        if instance is None:
            # instance attribute accessed on class, return self
            return self
        
        # instance attribute accessed on instance, return value
        if (self.definition.cmax > 1):
            instance._property_values.setdefault(self.name, PropertyList(self.definition))
        
        return instance._property_values.get(self.name)
    
    def __set__(self, instance, value):
        if self.definition.cmax > 1: 
            if isinstance(value, list):
                # Create the list if necessary
                instance._property_values.setdefault(self.name, PropertyList(self.definition))

                # Clear the list
                del instance._property_values[self.name][:]

                # Populate the list with the new values
                for item in value:
                    instance._property_values[self.name].append(item)
            
            else:
                raise PropertyCardinalityError('set', self.definition)

        else:
            instance._property_values[self.name] = self.coerce_type(value)

    
    def __repr__(self):
        s = 'Property({})'.format(self.definition)
        return s
# class Property

class PropertyList(list, PropertyMixin):
    """PropertyList is used by Property when cardinality > 1."""
    
    def __init__(self, definition, *args, **kwargs):
        """Create a new PropertyList instance.
        Note that minimum cardinality is not enforced when calling 'append'.
         
        :param PropertyDefinition definition: Description of the property.
        """
        super(PropertyList, self).__init__(*args, **kwargs)
        self.definition = definition

    def insert(self, i, x):
        """Insert a value into the list at position i."""
        # This raises a PropertyTypeError if x has an incorrect value.
        x = self.coerce_type(x)
        
        if len(self) >= self.definition.cmax:
            raise PropertyCardinalityError('insert', self.definition)
            
        super(PropertyList, self).insert(i, x)
         
    def append(self, x):
        """Append a value to the list."""
        # This raises a PropertyTypeError if x has an incorrect value.
        x = self.coerce_type(x)
        
        if len(self) >= self.definition.cmax:
            raise PropertyCardinalityError('append', self.definition)
            
        super(PropertyList, self).append(x)
    
    def toNative(self):
        return [i.toNative() for i in self]
# class PropertyList   


# ------------------------------------------------------------------------------
# Base classes
# ------------------------------------------------------------------------------
class FHIRBase(object):
    """Base class for all FHIR resources and elements."""
    _allowed_attributes = ['_property_values']

    def __init__(self, **kwargs):
        """Create a new instance."""
        self._property_values = dict()
        for attr, value in kwargs.items():
            setattr(self, attr, value)
    # def __init__
    
    def __setattr__(self, attr, value):
        """x.attr = value <==> setattr(x, attr, value)

            Additionally, raises an InvalidAttributeError when trying to assign a 
            value to an attribute that is not part of the Resource/Element definition.
        """
        if (attr not in self._allowed_attributes) and (attr not in self._getProperties()):
            raise InvalidAttributeError(type(self).__name__, attr)

        super().__setattr__(attr, value)
    # def __setattr__

    def _getProperties(self):
        """Return a list of attribute names that are of type 'Property'. 
        
            The list is sorted by order of definition.
        """
        properties = []
        for attr in dir(type(self)):
            a = getattr(type(self), attr)
            if isinstance(a, Property):
                properties.append(a)
                
        properties.sort(key=lambda i: i._creation_order)
        properties = [p.definition.name for p in properties]
        
        return properties
    # def _getProperties

    @classmethod
    def marshallXML(cls, xmlstring):
        """Marshall a Resource from its XML representation."""
        # Remove the default namespace definition, makes life a bit easier
        # when using ElementTree.
        xmlstring = re.sub('\\sxmlns="[^"]+"', '', xmlstring, count=1)
        
        # Parse the string using ElementTree
        root = ET.fromstring(xmlstring)
        
        # Sanity check
        if root.tag != cls.__name__:
            print('*** WARNING: trying to marshall a {} in a {} ***'.format(root.tag, cls.__name__))
        
        return cls()._marshallXML(root)
    # def marshallXML_
    
    def _getPropertyDetailsForTag(self, name):
        """Return Property and (expected) type for attribute with 'name'."""
        if not hasattr(self.__class__, name):
            # We might be dealing with a value[x] property!
            for attr in self._getProperties():
                if name.startswith(attr):
                    # valueBoolean --> boolean
                    type_ = lower_first_letter(name.replace(attr, ''))
                    
                    # valueBoolean --> value
                    name = attr
                    break
            else:
                # If no break occurred.
                msg = "Cannot find property '{}' on resource '{}'"
                raise Exception(msg.format(name, self.__class__.__name__))
        else:
            type_ = ''
        
        # Get the Property
        property_ = getattr(self.__class__, name)        

        # If type_ was not explicitly defined by the tag name, get it from the
        # definition.
        if not type_:
            type_ = property_.definition.type
        
        # definition.type may be a string to facilitate lazy evaluation.
        type_ = get_type(type_)

        return property_, property_.definition, type_
    # def _getPropertyForTag
    
    def _marshallXML(self, xml):
        # Iterate over *my* properties.
        for tag in xml:
            ns, tag_name = split_namespace(tag)
            prop, prop_def, prop_type = self._getPropertyDetailsForTag(tag_name)
            
            # If the namespace is xhtml, we shouldn't parse the tree any 
            # further and just try to assign the xhtml to the property.
            if ns == 'http://www.w3.org/1999/xhtml':
                value = ET.tostring(tag, 'unicode')
                value = value.replace('html:', '')
                value = value.replace(':html', '')
            
            # Inline resources are handled a little differently
            elif issubclass(prop_type, Resource):
                children = list(tag)
                resource_element = children[0]
                resource_type = get_type(resource_element.tag)
                value = resource_type()
                value._marshallXML(resource_element)
                
            # Then it must be a simple or complex type
            else:
                value = prop_type(**tag.attrib)
                value._marshallXML(tag)

            if prop_def.cmax == 1:
                setattr(self, prop.name, value)
            elif prop_def.cmax > 1:
                getattr(self, prop.name).append(value)

        return self
    # def _marshallXML

    @classmethod
    def fromPythonObject(cls, python_object, level=1, type_=None):
        """python_object can be a dict, list, str, int, float, bool."""
        try:
            resourceType = python_object.pop('resourceType')

            if resourceType != cls.__name__:
                print('*** WARNING: trying to marshall a {} in a {} ***'.format(resourceType, cls.__name__))
        except:
            pass

        spaces = ' ' * level

        if isinstance(python_object, dict):
            # dict --> resource or complex type
            instance = cls()

            # First process any entries prefixed with an underscore ('_')
            for attr_name, attr_value in python_object.items():
                if not attr_name.startswith('_'):
                    continue

                attr_name = attr_name.replace('_', '')
                attr_cls = getattr(cls, attr_name).definition.type
                if isinstance(attr_cls, str):
                    attr_cls = getattr(sys.modules[__name__], attr_cls)

                # instance.attr_name = attr_cls.fromPythonObject(attr_value)
                setattr(instance, attr_name, attr_cls.fromPythonObject(attr_value, level+1))

            # Next, process all regular entries.
            for attr_name, attr_value in python_object.items():
                if attr_name.startswith('_'):
                    continue
                
                attr_cls = getattr(cls, attr_name).definition.type
                if isinstance(attr_cls, str):
                    attr_cls = getattr(sys.modules[__name__], attr_cls)
                
                attr = getattr(instance, attr_name)

                if isinstance(attr, Element):
                    # Existing attribute (already set through underscore definition)
                    # Need to *update* the existing thing instead of replacing it.
                    attr.value = attr_value

                else:
                    setattr(instance, attr_name, attr_cls.fromPythonObject(attr_value, level+1))

            return instance

        if isinstance(python_object, list):
            # list --> PropertyList
            return [cls.fromPythonObject(i) for i in python_object]

        # simple value!
        return python_object
    # def fromPythonObject

    @classmethod
    def marshallJSON(cls, jsonstring):
        """Marshall a Resource from its JSON representation."""
        jsondict = json.loads(jsonstring)
        return cls.fromPythonObject(jsondict)
    # def marshallJSON

    def serialize(self, format_='xml'):
        if format_ in ['xml', 'json']:
            format_ = format_.upper()
            func = getattr(self, 'to' + format_)
            return func()
    # def serialize

    def toNative(self):
        return self.toDict()
    # def toNative

    def toDict(self, level=0):
        """Return a dictionary representation of this object."""
        retval = dict()

        if isinstance(self, Resource):            
            retval['resourceType'] = self.__class__.__name__

        # Iterate over *my* attributes.
        for attr in self._getProperties():
            property_def = getattr(type(self), attr).definition
            value = getattr(self, attr)

            if isinstance(value, BaseType):
                if isinstance(property_def.type, list):
                    class_name = upper_first_letter(value.__class__.__name__)
                    attr = attr + class_name 

                v = value.toNative()
                if value != None:
                    retval[attr] = v

                json_dict = value.toDict(level)
                if json_dict:
                    retval['_' + attr] = json_dict
                
            elif isinstance(value, PropertyList):
                listvalues = list()
                _listvalues = list()

                for v in value:
                    if isinstance(v, BaseType):
                        listvalues.append(v.toNative())
                        _v = v.toDict()
                        if not _v:
                            _v = None
                        _listvalues.append(_v)
                    else:
                        listvalues.append( v.toDict(level+1) )
                
                if listvalues:
                    retval[attr] = listvalues

                # Note that '!=' is used here on purpose!
                if sum(map(lambda x: x != None, _listvalues)) > 0:
                    retval['_' + attr] = _listvalues

            elif isinstance(value, Element):
                json_dict = value.toDict(level+1)

                if json_dict:
                    retval[attr] = json_dict
            
        return retval
    # def toDict
    
    def toJSON(self):
        """Return a JSON representation of this object."""
        return json.dumps(self.toDict(), indent=4)
    # def toJSON
    
    def toXML(self, parent, path):
        """Return an XML representation of this object."""
        # Iterate over *my* attributes.
        for attr in self._getProperties():
            value = getattr(self, attr)
            desc = getattr(type(self), attr).definition
            path_str = '.'.join(path + [attr, ])
            
            if value is not None:
                if desc.repr == 'xmlAttr':
                    parent.set(attr, str(value))
            
                elif desc.repr == 'text':
                    parent.append( ET.fromstring(str(value)) )
                
                elif isinstance(value, PropertyList):
                    for p in value:
                        p.toXML(ET.SubElement(parent, attr), path + [attr, ])
                        
                elif isinstance(value, FHIRBase):
                    if isinstance(desc.type, list):
                        class_name = upper_first_letter(value.__class__.__name__)
                        attr = attr + class_name 
                    value.toXML(ET.SubElement(parent, attr), path + [attr, ])
                
                else:
                    print(value, type(value))
                    raise Exception('unknown property type!?')
        
        # Only the root element needs to generate the actual XML.
        if len(path) == 1:
            x = xml.dom.minidom.parseString(ET.tostring(parent)) 
            pretty_xml = x.toprettyxml(indent='  ')

            if isinstance(self, Element):
                pretty_xml = pretty_xml.replace('<?xml version="1.0" ?>\n', '')
                
            return pretty_xml
    # def toXML
# class FHIRBase 
            
class Element(FHIRBase):
    """Base definition for all elements in a resource."""
    _timestamp = {{timestamp}}
    _url = 'http://hl7.org/fhir/StructureDefinition/Element'
    
    id = Property(PropertyDefinition('id', 'id', '0', '1'))
    extension = Property(PropertyDefinition('extension', 'Extension', '0', '*'))
    
    def toXML(self, parent=None, path=None):
        """Return an XML representation of this object."""
        if parent is None:
            tag = self.__class__.__name__
            path = [tag, ]
            parent = ET.Element(tag)
        
        return super().toXML(parent, path)
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

class Reference(Element):
    """
    A reference from one resource to another.
    
    Autogenerated class.
    """
    _url = 'http://hl7.org/fhir/StructureDefinition/Reference'
    
    reference = Property(PropertyDefinition('reference', 'string', '0', '1'))
    identifier = Property(PropertyDefinition('identifier', 'Identifier', '0', '1'))
    display = Property(PropertyDefinition('display', 'string', '0', '1'))
# class Reference

class BaseType(Element):
    """Base for basic/simple types."""

    def __init__(self, value=None, **kwargs):
        super().__init__(**kwargs)
        self.value = value
    
    def __repr__(self):
        """repr(x) <==> x.__repr__()"""
        return repr(self.value)

    def toNative(self):
        if self.value is None:
            return None
        
        type_ = type(self.value)
        return type_(self.value)
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
    _allowed_attributes = list(FHIRBase._allowed_attributes)
    _allowed_attributes.extend([
        '_value'
    ])

    _regex = None

    def __init__(self, value):
        super().__init__(value)

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
        elif self._regex is None:
            self._value = value
        else:
            args = [value, self.__class__.__name__]
            raise ValueError('"{}" is not a valid {}'.format(*args))
            
    def __repr__(self):
        return repr(self._value)
    
    def __str__(self):
        return self._value
# class dateTimeBase 


# Import basic types into module/package 'fhir.model'
{% for t in basic_types %}
from ._{{t.classname.lower()}} import {{t.classname}}
{% endfor %}

# Import complex types and resources into module/package 'fhir.model'
# from fhir.resource import Resource
from .resource import Resource
{% for t in processed_items if not t in ['FHIRBase', 'Element', 'Extension','Resource', 'Reference'] %}
from .{{t.lower()}} import {{t}}
{% endfor %}

# __all__ = [{% for t in types %}'{{t.classname}}', {% endfor %}]