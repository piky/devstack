#!/bin/bash

# This is a small helper to speed development and debug with devstack.
# It is intended to help you run a single function in a project module
# without having to re-stack.
#
# For example, to run the just start_glance function, do this:
#
#   ./tools/debug_function.sh glance start_glance

if [ ! -f "lib/$1" ]; then
    echo "Usage: $0 [project] [function] [function...]"
fi

source stackrc
set -x
while [ "$1" ]; do
    if [ -f "lib/$1" ]; then
        echo === Loading lib/$1 ===
        source lib/$1
    else
        echo ==== Running $1 ====
        $1
        echo ==== Done with $1 ====
    fi
    shift
done
