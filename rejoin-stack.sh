#! /usr/bin/env bash

# This script rejoins an existing screen, or re-creates a
# screen session from a previous run of stack.sh.

TOP_DIR=$(cd $(dirname "$0") && pwd)

# Load local configuration
source $TOP_DIR/stackrc

# Like for stack.sh, we do not run as root.
if [[ $EUID -eq 0 ]]; then
    echo "You are running this script as root."
    if ! getent passwd stack >/dev/null; then
        echo "No 'stack' user was previously created. Have you run stack.sh before?"
        exit 1
    fi
    echo "We will run this as user 'stack' instead."

    STACK_DIR="$DEST/${TOP_DIR##*/}"
    exec su -c "set -e; cd $STACK_DIR; bash rejoin-stack.sh" stack
    exit 1
fi

# if screenrc exists, run screen
if [[ -e $TOP_DIR/stack-screenrc ]]; then
    if screen -ls | egrep -q "[0-9].stack"; then
        echo "Attaching to already started screen session.."
        exec screen -r stack
    fi
    exec screen -c $TOP_DIR/stack-screenrc
fi

echo "Couldn't find $TOP_DIR/stack-screenrc file; have you run stack.sh yet?"
exit 1
