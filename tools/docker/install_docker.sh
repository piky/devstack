#!/usr/bin/env bash

# **install_docker.sh**

# install_docker.sh
#
# Install docker

# Keep track of the current directory
SCRIPT_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $SCRIPT_DIR/../..; pwd)

# Import common functions
source $TOP_DIR/functions

# Load local configuration
source $TOP_DIR/stackrc

FILES=$TOP_DIR/files

# We need more configuration bits...
source $TOP_DIR/lib/glance

# Get our defaults
source $TOP_DIR/lib/nova_plugins/hypervisor-docker


# Set up admin creds based on stack.sh defaults
export OS_AUTH_URL=$SERVICE_ENDPOINT
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASSWORD


# Install Docker Service
# ======================

# Set up home repo
install_package python-software-properties && \
    sudo sh -c "echo deb $DOCKER_APT_REPO docker main > /etc/apt/sources.list.d/docker.list"
apt_get update
install_package --force-yes lxc-docker=${DOCKER_PACKAGE_VERSION}

# Start the daemon - restart just in case the package ever auto-starts...
restart_service docker

echo "Waiting for docker daemon to start..."
DOCKER_GROUP=$(groups | cut -d' ' -f1)
CONFIGURE_CMD="while ! /bin/echo -e 'GET /v1.3/version HTTP/1.0\n\n' | socat - unix-connect:$DOCKER_UNIX_SOCKET | grep -q '200 OK'; do
    # Set the right group on docker unix socket before retrying
    sudo chgrp $DOCKER_GROUP $DOCKER_UNIX_SOCKET
    sudo chmod g+rw $DOCKER_UNIX_SOCKET
    sleep 1
done"
if ! timeout $SERVICE_TIMEOUT sh -c "$CONFIGURE_CMD"; then
    die $LINENO "docker did not start"
fi


# Get Docker image
if [[ ! -r $FILES/docker-ut.tar.gz ]]; then
    (cd $FILES; curl -OR $DOCKER_IMAGE)
fi
if [[ ! -r $FILES/docker-ut.tar.gz ]]; then
    die $LINENO "Docker image unavailable"
fi
docker import - $DOCKER_IMAGE_NAME <$FILES/docker-ut.tar.gz

# We need some configuration...$HOST_IP...maybe $SERVICE_IP?
docker tag $DOCKER_IMAGE_NAME $DOCKER_REPOSITORY_NAME

# Get Docker registry image
if [[ ! -r $FILES/docker-registry.tar.gz ]]; then
    (cd $FILES; curl -OR $DOCKER_REGISTRY_IMAGE)
fi
if [[ ! -r $FILES/docker-registry.tar.gz ]]; then
    die $LINENO "Docker registry image unavailable"
fi
docker import - $DOCKER_REGISTRY_IMAGE_NAME <$FILES/docker-registry.tar.gz


# Start a registry container
docker run -d -p ${DOCKER_REGISTRY_PORT}:5000 \
    -e SETTINGS_FLAVOR=openstack -e OS_USERNAME=${OS_USERNAME} \
    -e OS_PASSWORD=${OS_PASSWORD} -e OS_TENANT_NAME=${OS_TENANT_NAME} \
    -e OS_GLANCE_URL="${SERVICE_PROTOCOL}://${GLANCE_HOSTPORT}" \
    -e OS_AUTH_URL=${OS_AUTH_URL} \
    $DOCKER_REGISTRY_IMAGE_NAME ./docker-registry/run.sh

echo "Waiting for docker registry to start..."
DOCKER_REGISTRY=${SERVICE_HOST}:${DOCKER_REGISTRY_PORT}
if ! timeout $SERVICE_TIMEOUT sh -c "while ! curl -s $DOCKER_REGISTRY; do sleep 1; done"; then
    die $LINENO "docker-registry did not start"
fi

# Make sure we copied the image in Glance
DOCKER_IMAGE=$(glance image-list | egrep " $DOCKER_IMAGE_NAME ")
if ! is_set DOCKER_IMAGE ; then
    docker push $DOCKER_REPOSITORY_NAME
fi
