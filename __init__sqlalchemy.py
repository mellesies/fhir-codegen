# -*- coding: utf-8 -*-
"""Database Model declarations."""
from __future__ import unicode_literals, print_function

import datetime, time
import logging

import sqlalchemy
from sqlalchemy import *
from sqlalchemy.engine.url import make_url
from sqlalchemy.orm import scoped_session, sessionmaker, relationship, backref
from sqlalchemy.ext.declarative import declarative_base, as_declarative, declared_attr

Session = scoped_session(sessionmaker(autocommit=False, autoflush=False))
object_session = Session.object_session


# ------------------------------------------------------------------------------
# Base
# ------------------------------------------------------------------------------
@as_declarative()
class Base(object):
    """Base class."""

    @declared_attr
    def __tablename__(cls):
        return cls.__name__.lower()

    __table_args__ = {'mysql_engine': 'InnoDB'}

    def __iter__(self):
        """x.__iter__() <==> iter(x)"""
        keys = inspect(self.__class__).columns.keys()
        values = [getattr(self, key) for key in keys]
        return iter(zip(keys, values))
    # def __iter__

    @property
    def log(self):
        return logging.getLogger(self.__class__.__name__)

    @property
    def session(self):
        return Session()

    def save(self):
        """Commit any changes to the database."""
        session = Session.object_session(self)

        if session is None:
            session = self.session
            session.add(self)

        session.commit()

# ------------------------------------------------------------------------------
# Example
# ------------------------------------------------------------------------------
class Example(Base):
    """Example DB model class."""

    id = Column(Integer, primary_key=True)

    # Attributes
    name = Column(String(50))
    state = Column(Boolean)

