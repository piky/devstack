#!/bin/bash

# this runs a series of unit tests for devstack to ensure it's functioning

LIBS=`find lib -type f | grep -v \.md`
SCRIPTS=`find . -type f -name \*\.sh`
EXTRA="functions"

echo "Running bash8..."

./tools/bash8.py $SCRIPTS $LIBS $EXTRA
