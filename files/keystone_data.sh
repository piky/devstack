#!/bin/bash
#
# Initial data for Keystone using python-keystoneclient
#
# Tenant               User         Roles
# ------------------------------------------------------------------
# service              glance       service
# service              glance-swift ResellerAdmin
# service              heat         service        # if enabled
# service              ceilometer   admin          # if enabled
# Tempest Only:
# alt_demo             alt_demo     Member
#
# Variables set before calling this script:
# SERVICE_TOKEN - aka admin_token in keystone.conf
# SERVICE_ENDPOINT - local Keystone admin endpoint
# SERVICE_TENANT_NAME - name of tenant containing service accounts
# SERVICE_HOST - host used for endpoint creation
# ENABLED_SERVICES - stack.sh's list of services to start
# DEVSTACK_DIR - Top-level DevStack directory
# KEYSTONE_CATALOG_BACKEND - used to determine service catalog creation

# Defaults
# --------

ADMIN_PASSWORD=${ADMIN_PASSWORD:-secrete}
SERVICE_PASSWORD=${SERVICE_PASSWORD:-$ADMIN_PASSWORD}
export SERVICE_TOKEN=$SERVICE_TOKEN
export SERVICE_ENDPOINT=$SERVICE_ENDPOINT
SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}

# Roles
# -----

# The ResellerAdmin role is used by Nova and Ceilometer so we need to keep it.
# The admin role in swift allows a user to act as an admin for their tenant,
# but ResellerAdmin is needed for a user to act as any tenant. The name of this
# role is also configurable in swift-proxy.conf
keystone role-create --name=ResellerAdmin
# Service role, so service users do not have to be admins
keystone role-create --name=service


# Services
# --------

if [[ "$ENABLED_SERVICES" =~ "n-api" ]] && [[ "$ENABLED_SERVICES" =~ "s-proxy" || "$ENABLED_SERVICES" =~ "swift" ]]; then
    # Nova needs ResellerAdmin role to download images when accessing
    # swift through the s3 api.

    # Get reseller admin role if exists
    ROLE_RESELLER_ADMIN=$(keystone user-role-list --tenant $SERVICE_TENANT_NAME \
        --user nova | grep ResellerAdmin | awk '{ print $2}')
    if [[ -z "$ROLE_RESELLER_ADMIN" ]]; then
        # Create reseller admin role
        keystone user-role-add \
            --tenant $SERVICE_TENANT_NAME \
            --user nova \
            --role ResellerAdmin
    fi
fi

# Glance
if [[ "$ENABLED_SERVICES" =~ "g-api" ]]; then

    # Get glance user if exists
    GLANCE_USER=$(keystone user-list | grep " glance " | awk '{ print $2}')
    if [[ -z "$GLANCE_USER" ]]; then
        # Create glance user with roles
        keystone user-create \
            --name=glance \
            --pass="$SERVICE_PASSWORD" \
            --tenant $SERVICE_TENANT_NAME \
            --email=glance@example.com
        keystone user-role-add \
            --tenant $SERVICE_TENANT_NAME \
            --user glance \
            --role service
    fi

    # required for swift access
    if [[ "$ENABLED_SERVICES" =~ "s-proxy" ]]; then
        # Get glance-swift user if exists
        GLANCE_SWIFT_USER=$(keystone user-list | grep " glance-swift " | awk '{ print $2}')
        if [[ -z "$GLANCE_SWIFT_USER" ]]; then
            # Create glance-swift user with roles
            keystone user-create \
                --name=glance-swift \
                --pass="$SERVICE_PASSWORD" \
                --tenant $SERVICE_TENANT_NAME \
                --email=glance-swift@example.com
            keystone user-role-add \
                --tenant $SERVICE_TENANT_NAME \
                --user glance-swift \
                --role ResellerAdmin
        fi
    fi
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        # Get glance service if exists
        GLANCE_SERVICE=$(keystone service-list | grep " glance " | awk '{ print $2}')
        if [[ -z "$GLANCE_SERVICE" ]]; then
            # Create glance service
            keystone service-create \
                --name=glance \
                --type=image \
                --description="Glance Image Service"
        fi
        keystone endpoint-create \
            --region "$OS_REGION_NAME" \
            --service glance \
            --publicurl "http://$SERVICE_HOST:9292" \
            --adminurl "http://$SERVICE_HOST:9292" \
            --internalurl "http://$SERVICE_HOST:9292"
    fi
fi

# Ceilometer
if [[ "$ENABLED_SERVICES" =~ "ceilometer" ]] && [[ "$ENABLED_SERVICES" =~ "s-proxy" || "$ENABLED_SERVICES" =~ "swift" ]]; then
    # Ceilometer needs ResellerAdmin role to access swift account stats.

    # Get reseller admin role if exists
    ROLE_RESELLER_ADMIN=$(keystone user-role-list --tenant $SERVICE_TENANT_NAME \
        --user ceilometer | grep ResellerAdmin | awk '{ print $2}')
    if [[ -z "$ROLE_RESELLER_ADMIN" ]]; then
        # Create reseller admin role
        keystone user-role-add --tenant $SERVICE_TENANT_NAME \
            --user ceilometer \
            --role ResellerAdmin
    fi
fi

# EC2
if [[ "$ENABLED_SERVICES" =~ "n-api" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then

        # Get ec2 service if exists
        EC2_SERVICE=$(keystone service-list | grep " ec2 " | awk '{ print $2}')
        if [[ -z "$EC2_SERVICE" ]]; then
            # Create ec2 service
            keystone service-create \
                --name=ec2 \
                --type=ec2 \
                --description="EC2 Compatibility Layer"
        fi
        keystone endpoint-create \
            --region "$OS_REGION_NAME" \
            --service ec2 \
            --publicurl "http://$SERVICE_HOST:8773/services/Cloud" \
            --adminurl "http://$SERVICE_HOST:8773/services/Admin" \
            --internalurl "http://$SERVICE_HOST:8773/services/Cloud"
    fi
fi

# S3
if [[ "$ENABLED_SERVICES" =~ "n-obj" || "$ENABLED_SERVICES" =~ "swift3" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        # Get s3 service if exists
        S3_SERVICE=$(keystone service-list | grep " s3 " | awk '{ print $2}')
        if [[ -z "$S3_SERVICE" ]]; then
            # Create s3 service
            keystone service-create \
                --name=s3 \
                --type=s3 \
                --description="S3"
        fi
        keystone endpoint-create \
            --region "$OS_REGION_NAME" \
            --service s3 \
            --publicurl "http://$SERVICE_HOST:$S3_SERVICE_PORT" \
            --adminurl "http://$SERVICE_HOST:$S3_SERVICE_PORT" \
            --internalurl "http://$SERVICE_HOST:$S3_SERVICE_PORT"
    fi
fi

if [[ "$ENABLED_SERVICES" =~ "tempest" ]]; then
    # Tempest has some tests that validate various authorization checks
    # between two regular users in separate tenants
    TENANT=$(keystone tenant-list | grep " alt_demo " | awk '{ print $2}')
    if [[ -z "$TENANT" ]]; then
        keystone tenant-create \
            --name=alt_demo
    fi

    USER=$(keystone user-list | grep " alt_demo " | awk '{ print $2}')
    if [[ -z "$USER" ]]; then
        keystone user-create \
            --name=alt_demo \
            --pass="$ADMIN_PASSWORD" \
            --email=alt_demo@example.com
        keystone user-role-add \
            --tenant alt_demo \
            --user alt_demo \
            --role Member
    fi
fi

