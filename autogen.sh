#!/bin/bash
# find -E ./ -regex ".*\.(py|tpl)$" | entr sh -c "clear && ./generate.py"
cat files.txt | entr sh -c "clear && ./generate.py"
