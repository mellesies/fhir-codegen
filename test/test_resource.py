# -*- coding: utf-8 -*-
from __future__ import print_function
import unittest
import logging
import pprint

import xml.etree.ElementTree as ET
from formencode.doctest_xml_compare import xml_compare

import fhir
        

class TestResources(unittest.TestCase):
    
    def test_patient(self):
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

        p = fhir.Patient()
        p.id = 'http://fhir.zakbroek.com/Patient/1'
        p.active = True
        
        name = fhir.HumanName()
        name.use = 'official'
        name.given.append('Melle')
        name.given.append('Sjoerd')
        name.family.append('Sieswerda')
        p.name.append(name)
        # p.deceased = fhir.boolean(True)
        p.deceased = fhir.dateTime('2016-12-01T00:00:00Z')

        identifier = fhir.Identifier()
        identifier.value = '123456789'
        p.identifier.append(identifier)

        # print('')
        # print('')
        # print(p.toXML())