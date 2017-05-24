import sys
import os, os.path

import logging
import logging.handlers

import yaml

try:
  import db
except:
  pass
else:
  def setupDatabase(environment, config):
    uri = config['environments'][environment]['uri']
    db.configure(uri)
  

# class StreamToLogger(object):
#   """Fake file-like stream object that redirects writes to a logger instance."""
#   def __init__(self, logger, log_level=logging.INFO):
#     self.logger = logger
#     self.log_level = log_level
#     self.linebuf = ''
#    
#   def write(self, buf):
#     for line in buf.rstrip().splitlines():
#       self.logger.log(self.log_level, line.rstrip())
#   
#   def flush(self):
#     pass

class NullHandler(logging.Handler):
  def emit(self, record):
    pass

using_console_for_logging = False





def setupConfig(filename):
  config = yaml.load( open(filename) )
  return config


def setupLogging(config):
  """Setup a basic logging mechanism.
  
  @type  config: dict
  @param config: dict instance with the following keys in section 
    C{logging}: C{loglevel}, C{logfile}, C{format}, C{max_size}, C{backup_count}
    and C{use_console}.  
  """
  level = config["logging"]["level"]
  
  if level == 'NONE':
    return
  
  level = getattr(logging, level.upper())
  
  filename = config["logging"]["file"]
  format = config["logging"]["format"]
  bytes = config["logging"]["max_size"]
  backup_count = config["logging"]["backup_count"]
  
  # Create the root logger
  logger = logging.getLogger()
  logger.setLevel(level)
  
  # Create RotatingFileHandler
  rfh = logging.handlers.RotatingFileHandler(filename, 
                                             maxBytes=1024*bytes, 
                                             backupCount=backup_count)
  rfh.setLevel(level)
  rfh.setFormatter(logging.Formatter(format))
  logger.addHandler(rfh)
  
  # Check what to do with the console output ...
  if config["logging"]["use_console"]:
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(level)
    ch.setFormatter(logging.Formatter(format))
    logger.addHandler(ch)
    
    import util
    util.using_console_for_logging = True
    
  
  # Finally, capture all warnings using the logging mechanism.
  logging.captureWarnings(True)


def chdir(dirname):
  try:
    # This may fail if dirname == ''
    os.chdir(dirname)
  except:
    # print "Could not change directory to: '%s'" % dirname
    pass


def init(application, environment='test', config_file='config.yaml', setup_database=True):
  """Set the CWD, load the config file and setup logging."""
  # Read the command line parameters and change directory to the application
  # root. 
  app = sys.argv[0]
  dirname = os.path.dirname(app)
  
  if 'ipython' not in app:
    chdir(dirname)
  
  config = setupConfig(config_file)
  setupLogging(config['applications'][application])
  
  log = logging.getLogger(__name__)
  
  log.info("-" * 80)
  log.info("Started application '%s' with environment '%s'" % (application, environment))
  log.info("Current working directory is '%s'" % os.getcwd())
  log.info("Succesfully loaded configuration from '%s'" % config_file)
  
  if setup_database:
    log.info("Configuring database ...")
    setupDatabase(environment, config)
  
  return config
