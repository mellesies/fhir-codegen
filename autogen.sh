#!/bin/bash
# find -E ./ -regex ".*\.(py|tpl)$" | entr sh -c "clear && ./generate.py"

# Make sure the logs directory exists.
mkdir -p logs

# (re)generate the fhir module everytime one of the files in files.txt changes.  
cat files.txt | entr sh -c "clear && ./generate.py"
