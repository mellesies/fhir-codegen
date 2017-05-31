# -*- coding: utf-8 -*-
from __future__ import print_function
import unittest
import logging
import pprint

import xml.etree.ElementTree as ET
from formencode.doctest_xml_compare import xml_compare

import fhir.model

class TestResources(unittest.TestCase):
    
    def test_patientToJSON(self):
        xmlstring = """
            <Patient xmlns="http://hl7.org/fhir">
                <id value="http://fhir.zakbroek.com/Patient/1"/>
                <identifier>
                    <value value="123456789"/>
                </identifier>
                <active value="true"/>
                <name>
                    <use value="official"/>
                    <family value="Sieswerda"/>
                    <given value="Melle"/>
                    <given value="Sjoerd"/>
                </name>
                <deceasedBoolean value="true"/>
                <gender value="male"/> 
            </Patient>
        """
        p = fhir.model.Patient()

        extension = fhir.model.Extension()
        extension.url = 'http://some.sort.of.extension/definition'
        extension.value = fhir.model.string('this is a stringValue')
        p.extension.append(extension)

        p.id = 'http://fhir.zakbroek.com/Patient/1'
        p.active = True

        name = fhir.model.HumanName()
        name.use = 'official'
        name.given.append('Melle')
        name.given.append('Sjoerd')
        name.family.append('Sieswerda')
        name.given[0].id = 'this is an id on a given name'

        p.name.append(name)
        # p.deceased = fhir.model.boolean(True)
        p.deceased = fhir.model.dateTime('2016-12-01T00:00:00Z')

        identifier = fhir.model.Identifier()
        identifier.value = '123456789'
        identifier.system = 'urn:oid:1.2.36.146.595.217.0.1'
        p.identifier.append(identifier)

        print('')
        print('')
        print(p.toJSON())
        print('')

    def test_assignmentErrors(self):
        p = fhir.model.Patient()
        name = fhir.model.HumanName()

        with self.assertRaises(fhir.model.PropertyTypeError):
            p.active = 'this really should be a boolean'

        with self.assertRaises(fhir.model.PropertyCardinalityError):
            name.given = 'should have called append'
