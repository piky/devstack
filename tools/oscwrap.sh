#!/bin/bash

set -ue

RECORD=/tmp/osctime.txt

START=$(date +%s%3N)
out=$(openstack.real "$@")
rc=$?
END=$(date +%s%3N)
echo $(($END - $START)) >> $RECORD

echo "$out"
exit $rc
