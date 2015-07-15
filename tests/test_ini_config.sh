#!/usr/bin/env bash

# Tests for DevStack INI functions

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import config functions
source $TOP/inc/ini-config

source $TOP/tests/unittest.sh

set -e

echo "Testing INI functions"

# to increaes the degree of difficulty, we put the test file in a
# directory we can't write to, simulating a file we own in /etc
INI_TMP_DIR=$(mktemp -d)
INI_TMP_ETC_DIR=$INI_TMP_DIR/etc
TEST_INI=${INI_TMP_ETC_DIR}/test.ini
mkdir ${INI_TMP_ETC_DIR}

cat >${TEST_INI} <<EOF
[default]
# comment an option
#log_file=./log.conf
log_file=/etc/log.conf
handlers=do not disturb

[aaa]
# the commented option should not change
#handlers=cc,dd
handlers = aa, bb

[bbb]
handlers=ee,ff

[ ccc ]
spaces  =  yes

[ddd]
empty =

[eee]
multi = foo1
multi = foo2

# inidelete(a)
[del_separate_options]
a=b
b=c

# inidelete(a)
[del_same_option]
a=b
a=c

# inidelete(a)
[del_missing_option]
b=c

# inidelete(a)
[del_missing_option_multi]
b=c
b=d

# inidelete(a)
[del_no_options]

# inidelete(a)
# no section - del_no_section

EOF

chmod 555 ${INI_TMP_ETC_DIR}

# Test with missing arguments

BEFORE=$(cat ${TEST_INI})

echo -n "iniset: test missing attribute argument: "
iniset ${TEST_INI} aaa
NO_ATTRIBUTE=$(cat ${TEST_INI})
if [[ "$BEFORE" == "$NO_ATTRIBUTE" ]]; then
    passed
else
    failed "failed"
fi

echo -n "iniset: test missing section argument: "
iniset ${TEST_INI}
NO_SECTION=$(cat ${TEST_INI})
if [[ "$BEFORE" == "$NO_SECTION" ]]; then
    passed
else
    failed "failed"
fi

# Test with spaces

VAL=$(iniget ${TEST_INI} aaa handlers)
if [[ "$VAL" == "aa, bb" ]]; then
    passed "OK: $VAL"
else
    failed "iniget failed: $VAL"
fi

iniset ${TEST_INI} aaa handlers "11, 22"

VAL=$(iniget ${TEST_INI} aaa handlers)
if [[ "$VAL" == "11, 22" ]]; then
    passed "OK: $VAL"
else
    failed "iniget failed: $VAL"
fi

# Test with spaces in section header

VAL=$(iniget ${TEST_INI} " ccc " spaces)
if [[ "$VAL" == "yes" ]]; then
    passed "OK: $VAL"
else
    failed "iniget failed: $VAL"
fi

iniset ${TEST_INI} "b b" opt_ion 42

VAL=$(iniget ${TEST_INI} "b b" opt_ion)
if [[ "$VAL" == "42" ]]; then
    passed "OK: $VAL"
else
    failed "iniget failed: $VAL"
fi

# Test without spaces, end of file

VAL=$(iniget ${TEST_INI} bbb handlers)
if [[ "$VAL" == "ee,ff" ]]; then
    passed "OK: $VAL"
else
    failed "iniget failed: $VAL"
fi

iniset ${TEST_INI} bbb handlers "33,44"

VAL=$(iniget ${TEST_INI} bbb handlers)
if [[ "$VAL" == "33,44" ]]; then
    passed "OK: $VAL"
else
    failed "iniget failed: $VAL"
fi

# test empty option
if ini_has_option ${TEST_INI} ddd empty; then
    passed "OK: ddd.empty present"
else
    failed "ini_has_option failed: ddd.empty not found"
fi

# test non-empty option
if ini_has_option ${TEST_INI} bbb handlers; then
    passed "OK: bbb.handlers present"
else
    failed "ini_has_option failed: bbb.handlers not found"
fi

# test changing empty option
iniset ${TEST_INI} ddd empty "42"

VAL=$(iniget ${TEST_INI} ddd empty)
if [[ "$VAL" == "42" ]]; then
    passed "OK: $VAL"
else
    failed "iniget failed: $VAL"
fi

# test pipe in option
iniset ${TEST_INI} aaa handlers "a|b"

VAL=$(iniget ${TEST_INI} aaa handlers)
if [[ "$VAL" == "a|b" ]]; then
    passed "OK: $VAL"
else
    failed "iniget failed: $VAL"
fi

# test space in option
iniset ${TEST_INI} aaa handlers "a b"

VAL="$(iniget ${TEST_INI} aaa handlers)"
if [[ "$VAL" == "a b" ]]; then
    passed "OK: $VAL"
else
    failed "iniget failed: $VAL"
fi

# Test section not exist

VAL=$(iniget ${TEST_INI} zzz handlers)
if [[ -z "$VAL" ]]; then
    passed "OK: zzz not present"
else
    failed "iniget failed: $VAL"
fi

iniset ${TEST_INI} zzz handlers "999"

VAL=$(iniget ${TEST_INI} zzz handlers)
if [[ -n "$VAL" ]]; then
    passed "OK: zzz not present"
else
    failed "iniget failed: $VAL"
fi

# Test option not exist

VAL=$(iniget ${TEST_INI} aaa debug)
if [[ -z "$VAL" ]]; then
    passed "OK aaa.debug not present"
else
    failed "iniget failed: $VAL"
fi

if ! ini_has_option ${TEST_INI} aaa debug; then
    passed "OK aaa.debug not present"
else
    failed "ini_has_option failed: aaa.debug"
fi

iniset ${TEST_INI} aaa debug "999"

VAL=$(iniget ${TEST_INI} aaa debug)
if [[ -n "$VAL" ]]; then
    passed "OK aaa.debug present"
else
    failed "iniget failed: $VAL"
fi

# Test comments

inicomment ${TEST_INI} aaa handlers

VAL=$(iniget ${TEST_INI} aaa handlers)
if [[ -z "$VAL" ]]; then
    passed "OK"
else
    failed "inicomment failed: $VAL"
fi

# Test multiple line iniset/iniget
iniset_multiline ${TEST_INI} eee multi bar1 bar2

VAL=$(iniget_multiline ${TEST_INI} eee multi)
if [[ "$VAL" == "bar1 bar2" ]]; then
    echo "OK: iniset_multiline"
else
    failed "iniset_multiline failed: $VAL"
fi

# Test iniadd with exiting values
iniadd ${TEST_INI} eee multi bar3
VAL=$(iniget_multiline ${TEST_INI} eee multi)
if [[ "$VAL" == "bar1 bar2 bar3" ]]; then
    passed "OK: iniadd"
else
    failed "iniadd failed: $VAL"
fi

# Test iniadd with non-exiting values
iniadd ${TEST_INI} eee non-multi foobar1 foobar2
VAL=$(iniget_multiline ${TEST_INI} eee non-multi)
if [[ "$VAL" == "foobar1 foobar2" ]]; then
    passed "OK: iniadd with non-exiting value"
else
    failed "iniadd with non-exsting failed: $VAL"
fi

# Test inidelete
del_cases="
    del_separate_options
    del_same_option
    del_missing_option
    del_missing_option_multi
    del_no_options
    del_no_section"

for x in $del_cases; do
    inidelete ${TEST_INI} $x a
    VAL=$(iniget_multiline ${TEST_INI} $x a)
    if [ -z "$VAL" ]; then
        passed "OK: inidelete $x"
    else
        failed "inidelete $x failed: $VAL"
    fi
    if [ "$x" = "del_separate_options" -o \
        "$x" = "del_missing_option" -o \
        "$x" = "del_missing_option_multi" ]; then
        VAL=$(iniget_multiline ${TEST_INI} $x b)
        if [ "$VAL" = "c" -o "$VAL" = "c d" ]; then
            passed "OK: inidelete other_options $x"
        else
            failed "inidelete other_option $x failed: $VAL"
        fi
    fi
done

# cleanup
chmod 755 ${INI_TMP_ETC_DIR}
rm -rf ${INI_TMP_DIR}

report_results
