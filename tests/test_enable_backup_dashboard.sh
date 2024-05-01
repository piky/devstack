#!/bin/bash

# Simple test of enable backup dashboard

TOP=$(cd $(dirname "$0")/.. && pwd)

source $TOP/inc/ini-config
source $TOP/functions-common
source $TOP/lib/horizon
source $TOP/tests/unittest.sh

OUT_DIR=$(mktemp -d)

function test_enable_backup_dashboard {
    local file_localconf
    local file_localsettings
    local file_expectlocalsettings
    local ENABLE_BACKUP_DASHBOARD

    file_localsettings=`mktemp`
    file_expectlocalsettings=`mktemp`
    file_localconf=`mktemp`

    cat <<- EOF > $file_localconf
[[local|localrc]]
enable_service c-bak
ENABLE_BACKUP_DASHBOARD=True
EOF

    cat <<- EOF > $file_localsettings
WEBROOT = "/dashboard/"
EOF

    cat <<- EOF > $file_expectlocalsettings
WEBROOT = "/dashboard/"
OPENSTACK_CINDER_FEATURES = {'enable_backup': True}
EOF

    if [[ -n "$SUDO" ]]; then
        SUDO_ARG="-sudo"
    else
        SUDO_ARG=""
    fi
    source $file_localconf

    if is_service_enabled c-bak && [[ $ENABLE_BACKUP_DASHBOARD == "True" ]]; then
        _horizon_config_set $file_localsettings "" OPENSTACK_CINDER_FEATURES "{'enable_backup': True}"
    fi

    result=`cat $file_localsettings`
    result_expected=`cat $file_expectlocalsettings`

    assert_equal "$result" "$result_expected"

    rm -f $file_localconf $file_localsettings $file_expectlocalsettings
}

function test_not_enable_backup_dashboard {
    local file_localconf
    local file_localsettings
    local file_expectlocalsettings
    local ENABLE_BACKUP_DASHBOARD

    file_localsettings=`mktemp`
    file_expectlocalsettings=`mktemp`
    file_localconf=`mktemp`

    cat <<- EOF > $file_localconf
[[local|localrc]]
enable_service c-bak
EOF

    cat <<- EOF > $file_localsettings
WEBROOT = "/dashboard/"
EOF

    cat <<- EOF > $file_expectlocalsettings
WEBROOT = "/dashboard/"
EOF

    if [[ -n "$SUDO" ]]; then
        SUDO_ARG="-sudo"
    else
        SUDO_ARG=""
    fi
    source $file_localconf

    if is_service_enabled c-bak && [[ $ENABLE_BACKUP_DASHBOARD == "True" ]]; then
        _horizon_config_set $file_localsettings "" OPENSTACK_CINDER_FEATURES "{'enable_backup': True}"
    fi

    result=`cat $file_localsettings`
    result_expected=`cat $file_expectlocalsettings`

    assert_equal "$result" "$result_expected"

    rm -f $file_localconf $file_localsettings $file_expectlocalsettings
}

test_enable_backup_dashboard
test_not_enable_backup_dashboard
