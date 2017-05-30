#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import print_function
from collections import OrderedDict
from datetime import datetime
from time import time

import sys
import os
import logging
import xml.etree.ElementTree as ET
import textwrap

import base
from jinja2 import Template

ROOT_FOLDER='fhir'
MODEL_FOLDER='model'


def load_file_as_elementtree(filename):
    import re
    log = logging.getLogger(__name__)
    
    log.debug("Loading XML from '{}'".format(filename))
    with open(filename, 'r') as fp:
        xmlstring = fp.read()
 
        # Remove the default namespace definition (xmlns="http://some/namespace")
        xmlstring = re.sub('\\sxmlns="[^"]+"', '', xmlstring, count=1)
        return ET.fromstring(xmlstring)
# def load_file_as_elementtree

def get_structure_definitions(*trees):
    """Extract StructureDefinition resources from XML trees.
    
    :param list *trees: list of trees with resources.
    :returns dict
    """
    log = logging.getLogger(__name__)
    
    structure_definition_list = list()
    
    for tree in trees:
        structure_definition_list.extend( tree.findall('.//StructureDefinition') )
        
    structure_definitions = dict()
    
    for sd in structure_definition_list:
        sd_name = sd.find('id').get('value')
        structure_definitions[sd_name] = sd
    
    return structure_definitions
# def get_structure_definitions

# ------------------------------------------------------------------------------
# Generate source
# ------------------------------------------------------------------------------
def write_package_init():

    with open('template/template__package__init__.tpl') as fp:
        tpl = fp.read()
    
    filename = os.path.join(ROOT_FOLDER, '__init__.py')
    t = Template(tpl, lstrip_blocks=True, trim_blocks=True)
    t.stream().dump('{}'.format(filename))
    


def write_model_init(processed_items=None):
    if processed_items is None:
        processed_items = list()
    
    basic_types = list()
    
    for type_, primitive in base.PRIMITIVE_TYPES.items():
        parameters = {
            'classname': type_,
        }
        basic_types.append(parameters)

    with open('template/template___init__.tpl') as fp:
        tpl = fp.read()

    kwargs = {
        'basic_types': basic_types, 
        'processed_items': processed_items,
        'timestamp': int(time()),
    }

    folder = os.path.join(ROOT_FOLDER, MODEL_FOLDER)
    t = Template(tpl, lstrip_blocks=True, trim_blocks=True)
    t.stream(**kwargs).dump('{}/__init__.py'.format(folder))
# def write_model_init

def write_basic_types(structure_definitions):
    log = logging.getLogger(__name__)
    
    with open('template/template_type.tpl') as fp:
        tpl = fp.read()

    t =  Template(tpl, lstrip_blocks=True, trim_blocks=True)

    for type_, primitive in base.PRIMITIVE_TYPES.items():
        # FIXME: for some reason the Narrative resource defines a type 'xhtml'
        #        which has *no* structuredefinition!?
        try:
            sd = structure_definitions[type_]
        except KeyError:
            sd = structure_definitions['string']
        
        snapshot = sd.find('.//snapshot')
        
        extension = snapshot.find('.//extension[@url="http://hl7.org/fhir/StructureDefinition/structuredefinition-regex"]')
        if extension is not None:
            regex = extension.find('valueString').get('value')
        else:
            regex = None
        
        log.debug('Writing/generating "{}"' .format(type_))
        parameters = {
            'classname': type_,
            'superclass': 'Element',
            'primitive': primitive,
            'regex': regex,
        }
    
        folder = os.path.join(ROOT_FOLDER, MODEL_FOLDER)
        t.stream(t=parameters, methods=base.METHODS).dump('{}/_{}.py'.format(folder, type_.lower()))
# def write_basic_types

def write_items(structure_definitions, items, processed=None):
    log = logging.getLogger(__name__)
    
    if processed is None:
        processed = list()
    
    with open('template/template_item.tpl') as fp:
        tpl = fp.read()

    t =  Template(tpl, lstrip_blocks=True, trim_blocks=True)
    
    for name in items:
        if name in ['FHIRBase', 'Element', 'Extension']:
            continue
        
        log.debug('Writing/generating "{}"'.format(name))
        resource, classes, dependencies = item_from_structure_definition(name, structure_definitions)
        
        kwargs = {
            'r': resource,
            'classes': classes,
        }
        
        folder = os.path.join(ROOT_FOLDER, MODEL_FOLDER)
        t.stream(**kwargs).dump('{}/{}.py'.format(folder, name.lower()))
        
        unprocessed_dependecies  = [dep for dep in dependencies if dep not in processed]
        processed = processed + unprocessed_dependecies
        write_items(structure_definitions, unprocessed_dependecies, processed)
    
    processed = processed + items
    processed.sort()
    return processed
# def write_items

def getValue(element, name, default=None):
    if (element is None) or (element.find(name) is None):
        return default
        
    return element.find(name).get('value')
# def getValue


def item_from_structure_definition(name, structure_definitions):
    """Parses a StructureDefinition into a dictionary."""
    sd = structure_definitions[name]
    url = getValue(sd, 'url')   
    root = item = OrderedDict([
        ('url', url),
        ('name', name),
        ('superclass', 'FHIRBase'),
        ('attributes', OrderedDict()),
        ('required_basic_types', set()),
        ('required_complex_types', set()),
    ])

    implicit_classes = OrderedDict()
    dependencies = set()
    
    snapshot = sd.find('.//snapshot') 
    differential = sd.find('.//differential')
    
    # All properties are defined in 'element' tags. These are not nested, but
    # flat. Hierarchy is defined by the value of the 'path' tag.
    for e in differential.iter('element'):
        # Get the 'path' for the element. The resource itself also has an
        # element with path equal to the name of the resource (e.g. 
        # '<path value="Patient">'), so we'll strip the first component.
        path = getValue(e, 'path')
        path = path.split('.')
        path = path[1:]
        
        # Details like definition (mapped to __doc__) and type (mapped to 
        # superclass are found in the element)
        if len(path) == 0:
            # This is the root element for the item (e.g. path == 'Patient')
            item['docstring'] = textwrap.wrap(getValue(e, 'definition'))
            
            superclass_ = getValue(e.find('type'), 'code', 'FHIRBase')
            item['superclass'] = superclass_
            
            if superclass_ not in base.PRIMITIVE_TYPES.keys() and superclass_ != 'object':
                dependencies.add(superclass_)
        else:
            # This can be:
            # - an attribute to the resource (e.g. 'id')
            # - an element/attribute to an inline type (e.g. 'contact.name').
            
            # Get the parent and the attribute
            parent = root
            attr = path[-1].replace('[x]', '')
            
            if len(path) > 1:
                for component in path[:-1]:
                    parent = parent['attributes'][component]
                
            types_ = list()
            for type_ in e.findall('type'):
                t = getValue(type_, 'code')
                if t in base.PRIMITIVE_TYPES:
                    root['required_basic_types'].add(t)
                elif t in base.COMPLEX_TYPES:
                    root['required_complex_types'].add(t)
                    dependencies.add(t) 
                
                if t == 'Reference':
                    url = getValue(type_, 'profile')
                    t = 'Reference(reference=\'{}\')'.format(url)
                    
                types_.append(t)
            
            if len(types_) > 1:
                type_ = types_
            else:
                type_ = types_[0]

            properties = OrderedDict([
                ('name', attr),
                ('min', getValue(e, 'min')),
                ('max', getValue(e, 'max')),
                ('type', type_), 
            ])
            
            if type_ in ['Element', 'BackboneElement']:
                # Snap, need to create an inline class/type/element.
                # This dict is stored (referenced) in two places!
                attrs = OrderedDict()
                ic = OrderedDict([
                    ('name', attr.title()),
                    ('superclass', type_),
                    ('attributes', attrs),
                ])

                implicit_classes[attr] = ic
                properties['type'] = attr.title()
                properties['attributes'] = attrs
                
            try:
                parent['attributes'][attr] = properties
            except:
                print(parent)
                print(attr)
                print(properties)
                raise
                
    return root, implicit_classes, dependencies
# def item_from_structure_definition      
  

def run(ftype, fresource, items, clear_model_folder=False):
    """Data Model.
        
    :param str ftype: filename for XML describing FHIR types
    :param str fresources: filename for XML describing FHIR resources
    :param list resources: resources to generate model for
    """
    log = logging.getLogger(__name__)
    
    # Get elementtrees for types and resources.
    et_types = load_file_as_elementtree(ftype)
    et_resources = load_file_as_elementtree(fresource)
    
    structure_definitions = get_structure_definitions(et_types, et_resources)
    
    if clear_model_folder:
        import shutil
        
        shutil.rmtree(os.path.join(ROOT_FOLDER, MODEL_FOLDER))
        os.makedirs(os.path.join(ROOT_FOLDER, MODEL_FOLDER))
                
    write_basic_types(structure_definitions)
    processed_items = write_items(structure_definitions, items)
    write_model_init(processed_items)
    write_package_init()
# def run
    
    
if __name__ == '__main__':
    # ./run.py input/profiles-types.xml input/profiles-resources.xml Patient
    
    if len(sys.argv) > 1:
        run(sys.argv[1], sys.argv[2], sys.argv[3:])
        
    else:
        import util
        config = util.init('generate', setup_database=False)
        config = config['applications']['generate']
        
        ftype = config['ftype']
        fresource = config['fresource']
        items = config['items']
        clear_model_folder = config['clear_model_folder']
        
        run(ftype, fresource, items, clear_model_folder)
        
            
    


