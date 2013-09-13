#!/usr/bin/env bash

# Tests for DevStack meta-config functions

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions

# Import config functions
source $TOP/lib/config

cat >test2a.conf <<EOF
[ddd]
type=original
EOF

cat >test.conf <<EOF
[[test1:test1a.conf]]
[default]
# comment an option
#log_file=./log.conf
log_file=/etc/log.conf
handlers=do not disturb

[aaa]
# the commented option should not change
#handlers=cc,dd
handlers = aa, bb

[[test1:test1b.conf]]
[bbb]
handlers=ee,ff

[ ccc ]
spaces  =  yes

[[test2:test2a.conf]]
[ddd]
type=new
additional=true

[[test1:test1c.conf]]
[eee]
multi = foo1
multi = foo2
EOF

echo -n "get_meta_section_files test1: "
VAL=$(get_meta_section_files test.conf test1)
EXPECT_VAL="test1a.conf
test1b.conf
test1c.conf"
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "get_meta_section_files test2: "
VAL=$(get_meta_section_files test.conf test2)
EXPECT_VAL="test2a.conf"
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "get_meta_section_files test3: "
VAL=$(get_meta_section_files test.conf test3)
EXPECT_VAL=""
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "get_meta_section test1c: "
VAL=$(get_meta_section test.conf test1 test1c.conf)
EXPECT_VAL="[eee]
multi = foo1
multi = foo2"
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "get_meta_section test2a: "
VAL=$(get_meta_section test.conf test2 test2a.conf)
EXPECT_VAL="[ddd]
type=new
additional=true"
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "get_meta_section test2z: "
VAL=$(get_meta_section test.conf test2 test2z.conf)
EXPECT_VAL=""
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "get_meta_section test3z: "
VAL=$(get_meta_section test.conf test3 test3z.conf)
EXPECT_VAL=""
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "get_meta_section nofile: "
VAL=$(get_meta_section nofile.ini test3)
EXPECT_VAL=""
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "get_meta_section nofile: "
VAL=$(get_meta_section nofile.ini test3 test3z.conf)
EXPECT_VAL=""
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "merge_config_file: "
merge_config_file test.conf test2 test2a.conf
VAL=$(cat test2a.conf)
EXPECT_VAL="[ddd]
additional = true
type=new"
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "merge_config_file: "
rm test2a.conf
merge_config_file test.conf test2 test2a.conf
VAL=$(cat test2a.conf)
# iniset adds a blank line if it creates the file...
EXPECT_VAL="
[ddd]
additional = true
type = new"
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "merge_config_group: "
rm test2a.conf
merge_config_group test.conf test2
VAL=$(cat test2a.conf)
# iniset adds a blank line if it creates the file...
EXPECT_VAL="
[ddd]
additional = true
type = new"
if [[ "$VAL" == "$EXPECT_VAL" ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "merge_config_group: "
rm test2a.conf
merge_config_group x-test.conf test2
if [[ ! -r test2a.conf ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

rm -f test.conf test2a.conf
