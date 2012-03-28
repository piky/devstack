#!/usr/bin/env bash

# **keystone.sh**

# Test keystone via the command line.

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Settings
# ========

# Use openrc + stackrc + localrc for settings
pushd $(cd $(dirname "$0")/.. && pwd)
source ./openrc
popd

# Generic timeout for operations
GENERIC_TIMEOUT=${GENERIC_TIMEOUT:-60}

# Generate randomized names for users and tenants
USER_1="user-$(openssl rand -hex 4)"
USER_2="user-$(openssl rand -hex 4)"
USER_3="user-$(openssl rand -hex 4)"
USER_4="user-$(openssl rand -hex 4)"
TENANT_1="test-$(openssl rand -hex 4)"
TENANT_2="test-$(openssl rand -hex 4)"

# Get member role id 
MEMBER_ID=`keystone role-list | grep Member | cut -d '|' -f2 | tr -d ' '`

# Create tenants and users recording their ids
TENANT_1_ID=`keystone tenant-create --name $TENANT_1 --enabled true | grep id | cut -d "|" -f3 | tr -d ' '`
TENANT_2_ID=`keystone tenant-create --name $TENANT_2 --enabled true | grep id | cut -d "|" -f3 | tr -d ' '`
USER_1_ID=`keystone user-create --name $USER_1 --pass password --enabled true | grep id | cut -d '|' -f3 | tr -d ' '`
USER_2_ID=`keystone user-create --name $USER_2 --pass password --enabled true | grep id | cut -d '|' -f3 | tr -d ' '`
USER_3_ID=`keystone user-create --name $USER_3 --pass password --enabled true | grep id | cut -d '|' -f3 | tr -d ' '`
USER_4_ID=`keystone user-create --name $USER_4 --pass password --enabled true | grep id | cut -d '|' -f3 | tr -d ' '`


# Add member role to user
#keystone user-role-add --user $USER_1_ID --role $MEMBER_ID --tenant_id $TENANT_1_ID
#keystone user-role-add --user $USER_2_ID --role $MEMBER_ID --tenant_id $TENANT_2_ID
#keystone user-role-add --user $USER_3_ID --role $MEMBER_ID --tenant_id $TENANT_1_ID
#keystone user-role-add --user $USER_4_ID --role $MEMBER_ID --tenant_id $TENANT_2_ID

# Cleanup users and tenants
keystone tenant-delete $TENANT_1_ID
keystone tenant-delete $TENANT_2_ID
keystone user-delete $USER_1_ID
keystone user-delete $USER_2_ID
keystone user-delete $USER_3_ID
keystone user-delete $USER_4_ID

# List, create and then delete from services
keystone service-list
SERVICE_NAME="service-$(openssl rand -hex 4)"
SERVICE_ID=`keystone service-create --name $SERVICE_NAME --type compute | grep id | cut -d '|' -f3 | tr -d ' '`
keystone service-delete $SERVICE_ID

# Check keystone discover and catalog are working
keystone discover
keystone catalog

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"


