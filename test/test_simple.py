# -*- coding: utf-8 -*-
from __future__ import print_function
import unittest
import logging
import pprint

import fhir
# import fhir

# class LoadDataAsElementTree(unittest.TestCase):
#
#     def test_load_types(self):
#         ftype = "input/profiles-types.xml"
#         et_types = run.load_file_as_elementtree(ftype)
#         self.assertIsNotNone(et_types)
#
#     def test_load_resources(self):
#         fresource = "input/profiles-resources.xml"
#         et_resources = run.load_file_as_elementtree(fresource)
#         self.assertIsNotNone(et_resources)
        

class TestTypes(unittest.TestCase):
    
    def test_x(self):
        p = fhir.Patient()
        p.id = 'http://fhir.zakbroek.com/Patient/1'
        
        name = fhir.HumanName()
        name.use = 'official'
        name.given.append('Melle')
        name.given.append('Sjoerd')
        name.family.append('Sieswerda')
        p.name.append(name)
        p.active = True

        identifier = fhir.Identifier()
        identifier.value = '123456789'
        p.identifier.append(identifier)

        # e = fhir.Extension()
        # e.url = 'http://hl7.org/fhir/StructureDefinition/patient-birthTime'
        # e.value = '2016-01-01T02:00:00Z'
        # p.id.extension.append(e)
        
        print()
        print()
        print(p.serialize('xml'))
        print()
    
    def test_string(self):
        t = 'test'
        s = fhir.string(t)
        
        self.assertTrue(isinstance(s, fhir.Element))
        self.assertTrue(hasattr(s, 'id'))
        self.assertTrue(hasattr(s, 'extension'))
        
        self.assertEquals(s, t)
        self.assertEquals(str(s), t)
        self.assertEquals(s+s, 2*t)
        self.assertEquals(3*s, 3*t)
        self.assertEquals(s*3, 3*t)
        
    def test_integer(self):
        t = 5
        i = fhir.integer(t)
        
        self.assertTrue(isinstance(i, fhir.Element))
        self.assertTrue(hasattr(i, 'id'))
        self.assertTrue(hasattr(i, 'extension'))
        
        self.assertEquals(i, t)
        self.assertEquals(i+i, 2*t)
        self.assertEquals(i+t, 2*t)
        self.assertEquals(t+i, 2*t)
        self.assertEquals(3*i, 3*t)

    def test_float(self):
        t = 5.0
        i = fhir.decimal(t)
        
        self.assertTrue(isinstance(i, fhir.Element))
        self.assertTrue(hasattr(i, 'id'))
        self.assertTrue(hasattr(i, 'extension'))
        
        self.assertEquals(i, t)
        self.assertEquals(i+i, 2*t)
        self.assertEquals(i+t, 2*t)
        self.assertEquals(t+i, 2*t)
        self.assertEquals(3*i, 3*t)
        self.assertEquals(i*3, 3*t)


    def test_boolean(self):
        t = fhir.boolean(True)
        f = fhir.boolean(False)
        
        self.assertTrue(isinstance(t, fhir.Element))
        self.assertTrue(hasattr(t, 'id'))
        self.assertTrue(hasattr(t, 'extension'))
        
        self.assertEquals(t, True)
        self.assertEquals(t and t, True)
        self.assertEquals(t or f, True)
        self.assertEquals(f, False)
    
    def test_dateTime(self):
        datetime_as_string = '2016-12-01T00:00:00Z'
        dt = fhir.dateTime(datetime_as_string)
        self.assertEquals(str(dt), datetime_as_string)
        self.assertRaises(ValueError, fhir.dateTime, '2016-12-01T00:00:01')
        self.assertRaises(ValueError, fhir.dateTime, '2016-12-01T00:01:00')
        self.assertRaises(ValueError, fhir.dateTime, '2016-12-01T01:00:00')
        
        
    def test_date(self):
        date_as_string = '2016-12-01'
        dt = fhir.date(date_as_string)
        self.assertEquals(str(dt), date_as_string)
        
    def test_time(self):
        dt = fhir.time('00:00:00')
        self.assertEquals(str(dt), '00:00:00')
        
