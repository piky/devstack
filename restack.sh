#!/usr/bin/env bash

# Reborn rejoin-stack.sh
# This borrows heavily from Grenade, to restart all the services
#
#


# Import Apache functions
source $TOP_DIR/lib/apache

# Import TLS functions
source $TOP_DIR/lib/tls

# Source project function libraries
source $TOP_DIR/lib/infra
source $TOP_DIR/lib/oslo
source $TOP_DIR/lib/lvm
source $TOP_DIR/lib/horizon
source $TOP_DIR/lib/keystone
source $TOP_DIR/lib/glance
source $TOP_DIR/lib/nova
source $TOP_DIR/lib/cinder
source $TOP_DIR/lib/swift
source $TOP_DIR/lib/heat
source $TOP_DIR/lib/neutron
source $TOP_DIR/lib/neutron-legacy
source $TOP_DIR/lib/ldap
source $TOP_DIR/lib/dstat
source $TOP_DIR/lib/dlm



########## Keystone

# Start Keystone
start_keystone

# ensure the service has started
ensure_services_started keystone


########### Swift

# Start Swift
start_swift

# Don't succeed unless the services come up
ensure_services_started swift-object-server swift-proxy-server
ensure_logs_exist s-proxy


########## Glance

# Start Glance
start_glance

# Don't succeed unless the services come up
ensure_services_started glance-api
ensure_logs_exist g-api g-reg


########### Neutron

# Start neutron and agents
start_neutron_third_party
start_neutron_service_and_check
start_neutron_agents

# Don't succeed unless the services come up
# TODO: service names ensure_services_started
ensure_logs_exist q-svc


############ Nova

# Start Nova
start_nova_api
start_nova

# Don't succeed unless the services come up
ensure_services_started nova-api nova-conductor nova-compute
ensure_logs_exist n-api n-cond n-cpu


############## Cinder

start_cinder

# Don't succeed unless the services come up
ensure_services_started cinder-api
ensure_logs_exist c-api c-vol



############## Horizon


# Start Horizon
start_horizon
