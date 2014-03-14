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
openstack role create ResellerAdmin
# Service role, so service users do not have to be admins
openstack role create service


# Services
# --------

if [[ "$ENABLED_SERVICES" =~ "n-api" ]] && [[ "$ENABLED_SERVICES" =~ "s-proxy" || "$ENABLED_SERVICES" =~ "swift" ]]; then
    # Nova needs ResellerAdmin role to download images when accessing
    # swift through the s3 api.
    openstack role add \
        ResellerAdmin \
        --project $SERVICE_TENANT_NAME \
        --user nova
fi

# Glance
if [[ "$ENABLED_SERVICES" =~ "g-api" ]]; then
    openstack user create \
        glance \
        --password "$SERVICE_PASSWORD" \
        --project $SERVICE_TENANT_NAME \
        --email glance@example.com
    openstack role add \
        service \
        --project $SERVICE_TENANT_NAME \
        --user glance
    # required for swift access
    if [[ "$ENABLED_SERVICES" =~ "s-proxy" ]]; then
        openstack user create \
            glance-swift \
            --password "$SERVICE_PASSWORD" \
            --project $SERVICE_TENANT_NAME \
            --email glance-swift@example.com
        openstack role add \
            ResellerAdmin \
            --project $SERVICE_TENANT_NAME \
            --user glance-swift
    fi
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        openstack service create \
            glance \
            --type image \
            --description "Glance Image Service"
        openstack endpoint create \
            glance \
            --region RegionOne \
            --publicurl "http://$SERVICE_HOST:9292" \
            --adminurl "http://$SERVICE_HOST:9292" \
            --internalurl "http://$SERVICE_HOST:9292"
    fi
fi

# Ceilometer
if [[ "$ENABLED_SERVICES" =~ "ceilometer" ]] && [[ "$ENABLED_SERVICES" =~ "s-proxy" || "$ENABLED_SERVICES" =~ "swift" ]]; then
    # Ceilometer needs ResellerAdmin role to access swift account stats.
    openstack role add \
        ResellerAdmin \
        --project $SERVICE_TENANT_NAME \
        --user ceilometer
fi

# EC2
if [[ "$ENABLED_SERVICES" =~ "n-api" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        openstack service create \
            ec2 \
            --type ec2 \
            --description "EC2 Compatibility Layer"
        openstack endpoint create \
            ec2 \
            --region RegionOne \
            --publicurl "http://$SERVICE_HOST:8773/services/Cloud" \
            --adminurl "http://$SERVICE_HOST:8773/services/Admin" \
            --internalurl "http://$SERVICE_HOST:8773/services/Cloud"
    fi
fi

# S3
if [[ "$ENABLED_SERVICES" =~ "n-obj" || "$ENABLED_SERVICES" =~ "swift3" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        openstack service create \
            s3 \
            --type s3 \
            --description "S3"
        openstack endpoint create \
            s3 \
            --region RegionOne \
            --publicurl "http://$SERVICE_HOST:$S3_SERVICE_PORT" \
            --adminurl "http://$SERVICE_HOST:$S3_SERVICE_PORT" \
            --internalurl "http://$SERVICE_HOST:$S3_SERVICE_PORT"
    fi
fi

# Tempest
if [[ "$ENABLED_SERVICES" =~ "tempest" ]]; then
    # Tempest has some tests that validate various authorization checks
    # between two regular users in separate tenants
    openstack project create \
        alt_demo
    openstack user create \
        alt_demo \
        --password "$ADMIN_PASSWORD" \
        --email alt_demo@example.com \
        --project alt_demo
    openstack role add \
        Member \
        --project alt_demo \
        --user alt_demo
fi
