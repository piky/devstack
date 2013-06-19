#! /usr/bin/env bash

# This script rejoins an existing screen, or re-creates a
# screen session from a previous run of stack.sh.

TOP_DIR=`dirname $0`

# Import common functions in case the localrc (loaded via stackrc)
# uses them.
source $TOP_DIR/functions

source $TOP_DIR/stackrc

# if screenrc exists, run screen
if [[ -e $TOP_DIR/stack-screenrc ]]; then
    if screen -ls | egrep -q "[0-9].stack"; then
        echo "Attaching to already started screen session.."
        exec screen -r stack
    fi
    screen -c $TOP_DIR/stack-screenrc -S $SCREEN_NAME
    if [ -n ${SCREEN_LOGDIR} ]; then
        cat $TOP_DIR/stack-screenrc | awk '$1~/screen/ {print $3}' | while read window; do
            cur_log=$(ls -lt ${SCREEN_LOGDIR}/screen-${window}* | awk 'NR <= 1 {print $NF}')
            if [ -f ${cur_log} ]; then
                ln -sf ${cur_log} ${SCREEN_LOGDIR}/screen-${window}.log
            fi
        done
    fi
else
    echo "Couldn't find $TOP_DIR/stack-screenrc file; have you run stack.sh yet?"
    exit 1
fi
