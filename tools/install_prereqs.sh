#!/usr/bin/env bash

# **install_prereqs.sh**

# Install system package prerequisites
#
# install_prereqs.sh [-f]
#
# -f        Force an install run now


if [[ -n "$1" &&  "$1" = "-f" ]]; then
    FORCE=1
fi

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP_DIR/functions

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro

# Needed to get ``ENABLED_SERVICES``
source $TOP_DIR/stackrc

# Minimum wait time
PREREQ_RERUN_MARKER=${PREREQ_RERUN_MARKER:-$TOP_DIR/.prereqs}
PREREQ_RERUN_HOURS=${PREREQ_RERUN_HOURS:-2}
PREREQ_RERUN_SECONDS=$((60*60*$PREREQ_RERUN_HOURS))

NOW=$(date "+%s")
LAST_RUN=$(head -1 $PREREQ_RERUN_MARKER)
DELTA=$(($NOW - $LAST_RUN))
if [[ $DELTA -lt $PREREQ_RERUN_SECONDS && -z "$FORCE" ]]; then
    echo "Re-run time has not expired ($(($PREREQ_RERUN_SECONDS - $DELTA)) seconds remaining); exiting..."
    exit 0
fi

# Proxy Settings
# --------------

# HTTP and HTTPS proxy servers are supported via the usual environment variables [1]
# ``http_proxy``, ``https_proxy`` and ``no_proxy``. They can be set in
# ``localrc`` if necessary or on the command line::
#
# [1] http://www.w3.org/Daemon/User/Proxies/ProxyClients.html
#
#     http_proxy=http://proxy.example.com:3128/ no_proxy=repo.example.net ./stack.sh

if [[ -n "$http_proxy" ]]; then
    export http_proxy=$http_proxy
fi
if [[ -n "$https_proxy" ]]; then
    export https_proxy=$https_proxy
fi
if [[ -n "$no_proxy" ]]; then
    export no_proxy=$no_proxy
fi


# Install Packages
# ================

# Install package requirements
if is_ubuntu; then
    install_package $(get_packages $FILES/apts)
elif is_fedora; then
    install_package $(get_packages $FILES/rpms)
elif is_suse; then
    install_package $(get_packages $FILES/rpms-suse)
else
    exit_distro_not_supported "list of packages"
fi

if [[ $SYSLOG != "False" ]]; then
    if is_ubuntu || is_fedora; then
        install_package rsyslog-relp
    elif is_suse; then
        install_package rsyslog-module-relp
    else
        exit_distro_not_supported "rsyslog-relp installation"
    fi
fi


# Mark end of run
# ---------------

date "+%s" >$PREREQ_RERUN_MARKER
date >>$PREREQ_RERUN_MARKER
