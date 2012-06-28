#!/usr/bin/env bash
#
# Stops that which is started by ``stack.sh`` (mostly)
# mysql and rabbit are left running as OpenStack code refreshes
# do not require them to be restarted.
#
# Stop all processes by setting UNSTACK_ALL or specifying ``--all``
# on the command line
#
# Stop a specific process by specifying ``-s $SERVICE_SHUT_DOWN`` or ``--service $SERVICE_SHUT_DOWN``
# on the command line. For example, unstack.sh -s g-reg.


# Keep track of the current devstack directory.
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions

# Load local configuration
source $TOP_DIR/stackrc

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
GetOSVersion

# Function to shut down all the services.
function shutdown_all_services {
    # Shut down devstack's screen to get the bulk of OpenStack services in one shot
    SCREEN=$(which screen)
    if [[ -n "$SCREEN" ]]; then
        SESSION=$(screen -ls | awk '/[0-9].stack/ { print $1 }')
        if [[ -n "$SESSION" ]]; then
            screen -X -S $SESSION quit
        fi
    fi

    # Swift runs daemons
    if is_service_enabled swift; then
        swift-init all stop
    fi

    # Apache has the WSGI processes
    if is_service_enabled horizon; then
        stop_service apache2
    fi

    # Get the iSCSI volumes
    if is_service_enabled n-vol; then
        TARGETS=$(sudo tgtadm --op show --mode target)
        if [[ -n "$TARGETS" ]]; then
            # FIXME(dtroyer): this could very well require more here to
            #                 clean up left-over volumes
            echo "iSCSI target cleanup needed:"
            echo "$TARGETS"
        fi
        stop_service tgt
    fi

    if [[ -n "$UNSTACK_ALL" ]]; then
        # Stop MySQL server
        if is_service_enabled mysql; then
            stop_service mysql
        fi
    fi
}

#Declare the parameters for getopt
declare unstackOptions
declare -r ScriptName=${0##*/}
declare -r ShortOpts="as:"
declare -r LongOpts="all,service:"

# Parse the parameters.
# Execute getopt.
unstackOptions=$(getopt -o "${ShortOpts}" --long \
  "${LongOpts}" --name "${ScriptName}" -- "${@}")

#No argument input.
if [[ ($# -eq 0) ]]; then
    UNSTACK_ALL=${UNSTACK_ALL:-1}
    shutdown_all_services
    exit 1
fi

#Preserve whitespaces inside options arguments.
eval set -- "$unstackOptions"

while true; do
  case "${1}" in
    -a | --all)
      UNSTACK_ALL=${UNSTACK_ALL:-1}
      shutdown_all_services
      exit 1
      ;;

    -s | -service)
      SERVICE_SHUT_DOWN="$2"
      ;;
     
    --)
      break
      ;;
      
  esac
  shift
done
shift

# If -s SERVICE_SHUT_DOWN is specified, just shut down the specific service. If -s SERVICE_SHUT_DOWN is not specified, shut down all the services.
if [[ -n "$SERVICE_SHUT_DOWN" ]]; then
    # Check if the service in available in ENABLED_SERVICE
    if is_service_enabled $SERVICE_SHUT_DOWN; then
        SCREEN=$(which screen)
        if [[ -n "$SCREEN" ]]; then
            SESSION=$(screen -ls | awk '/[0-9].stack/ { print $1 }')
            if [[ -n "$SESSION" ]]; then
                screen -S $SESSION -p $SERVICE_SHUT_DOWN -X stuff $'\003'
                sleep 1
                screen -S $SESSION -p $SERVICE_SHUT_DOWN -X stuff $'\004'
            fi
        fi
    else
        echo "$SERVICE_SHUT_DOWN is unable to shut down, because it is not running or it is not a valid service name."
    fi
fi