#!/usr/bin/env bash

# Tests for DevStack functions

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions

# Import configuration
source $TOP/openrc


echo "Testing die_if_not_zero()"

bash -c "source $TOP/functions; true; die_if_not_zero 'not OK'"
if [[ $? != 0 ]]; then
    echo "die_if_not_zero [true] Failed"
fi

bash -c "source $TOP/functions; false; die_if_not_zero 'OK'"
if [[ $? != 99 ]]; then
    echo "die_if_not_zero [false] Failed"
fi


echo "Testing die_if_not_set()"

bash -c "source $TOP/functions; X=`echo Y && true`; die_if_not_set X 'not OK'"
if [[ $? != 0 ]]; then
    echo "die_if_not_set [X='Y' true] Failed"
fi

bash -c "source $TOP/functions; X=`true`; die_if_not_set X 'OK'"
if [[ $? != 99 ]]; then
    echo "die_if_not_set [X='' true] Failed"
fi

bash -c "source $TOP/functions; X=`echo Y && false`; die_if_not_set X 'not OK'"
if [[ $? != 0 ]]; then
    echo "die_if_not_set [X='Y' false] Failed"
fi

bash -c "source $TOP/functions; X=`false`; die_if_not_set X 'OK'"
if [[ $? != 99 ]]; then
    echo "die_if_not_set [X='' false] Failed"
fi

