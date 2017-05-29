# -*- coding: utf-8 -*-
from __future__ import print_function
import unittest
import logging
import pprint

import xml.etree.ElementTree as ET
from formencode.doctest_xml_compare import xml_compare

import fhir
from fhir import Property, PropertyDefinition
from fhir import FHIRBase, Element, Extension
from fhir.backboneelement import BackboneElement
from fhir.domainresource import DomainResource

class Multiple(DomainResource):
    _url = 'urn:test'
    multi = Property(PropertyDefinition('multi', ['boolean', 'dateTime'], '0', '1'))


class TestMultiple(unittest.TestCase):
    
    def test_multipleBoolean(self):
        
        xmlstring = """
        <Multiple xmlns="http://hl7.org/fhir">
            <multiBoolean value="true"/>
        </Multiple>
        """

        m = Multiple()
        m.multi = fhir.boolean(True)

        x1 = ET.fromstring(xmlstring)
        x2 = ET.fromstring(m.toXML())

        # print('')
        # print('')
        # print(m.toXML())

        self.assertTrue(xml_compare(x1, x2), 'Serialized DomainReource does not match expected XML representation!')

    def test_multipleDateTime(self):
        
        xmlstring = """
        <Multiple xmlns="http://hl7.org/fhir">
            <multiDateTime value="2080-01-01T00:00:00Z"/>
        </Multiple>
        """

        m = Multiple()
        m.multi = fhir.dateTime("2080-01-01T00:00:00Z")

        x1 = ET.fromstring(xmlstring)
        x2 = ET.fromstring(m.toXML())

        self.assertTrue(xml_compare(x1, x2), 'Serialized DomainReource does not match expected XML representation!')

    def test_multipleAssignmentError(self):
        
        m = Multiple()
        
        with self.assertRaises(ValueError):
            m.multi = fhir.string('hello sweetie!')

