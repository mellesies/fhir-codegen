# -*- coding: utf-8 -*-
from __future__ import print_function
import unittest
import logging
import pprint

import xml.etree.ElementTree as ET
from formencode.doctest_xml_compare import xml_compare

import fhir.model
        

class TestSerialization(unittest.TestCase):
    
    def test_marshalXMLSimple(self):
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
                <gender value="male"/> 
                <deceasedBoolean value="true"/>
            </Patient>
        """
        p = fhir.model.Patient.marshallXML(xmlstring)
        x1 = ET.fromstring(xmlstring)
        x2 = ET.fromstring(p.toXML())

        self.assertTrue(xml_compare(x1, x2))

    @unittest.skip
    def test_marshallXMLWithDate(self):
        xmlstring = """
            <Patient xmlns="http://hl7.org/fhir">
                <id value="http://fhir.zakbroek.com/Patient/1"/>
                <birthDate value="1980-06-09"/>
            </Patient>
        """
        p = fhir.model.Patient.marshallXML(xmlstring)
        x1 = ET.fromstring(xmlstring)
        x2 = ET.fromstring(p.toXML())

        self.assertTrue(xml_compare(x1, x2))

    @unittest.skip
    def test_marshallXMLWithExtension(self):
        xmlstring = """
            <Patient xmlns="http://hl7.org/fhir">
                <id value="http://fhir.zakbroek.com/Patient/1"/>
                <birthDate value="1980-06-09">
                    <extension url="http://hl7.org/fhir/StructureDefinition/patient-birthTime">
                        <valueDateTime value="1974-12-25T14:35:45-05:00"/> 
                    </extension> 
                </birthDate>
            </Patient>
        """
        p = fhir.model.Patient.marshallXML(xmlstring)
        x1 = ET.fromstring(xmlstring)
        x2 = ET.fromstring(p.toXML())

        # print('')
        # print('')
        # print(p.toXML())
        # print(xmlstring)

        self.assertTrue(xml_compare(x1, x2))


    