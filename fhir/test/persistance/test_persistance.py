# -*- coding: utf-8 -*-
from __future__ import print_function
import unittest
import logging


from fhir.persistance import FHIRStore
import fhir.model
from fhir.model import *


class TestPersistance(unittest.TestCase):
    
    def test_post(self):
        store = FHIRStore(drop_all=True)
        
        p = Patient()
        p.id = 'http://fhir.zakbroek.com/Patient/1'
        p.active = True
        
        name = fhir.model.HumanName()
        name.use = 'official'
        name.given.append('Melle')
        name.given.append('Sjoerd')
        name.family.append('Sieswerda')
        p.name.append(name)
        # p.deceased = fhir.model.boolean(True)
        p.deceased = fhir.model.dateTime('2016-12-01T00:00:00Z')

        identifier = fhir.model.Identifier()
        identifier.value = '123456789'
        p.identifier.append(identifier)

        store.post(p)