#!/bin/bash
find ./ -name "*.py" | entr sh -c "clear && ./utest.py"
