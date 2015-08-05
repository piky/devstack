#!/bin/bash

# **tools/dstat.sh** - Execute instances of DStat to log system load info
#
# Multiple instances of DStat are executed in order to take advantage of
# incompatible features, particularly CSV output and the "top-cpu-adv" and
# "top-io-adv" flags.
#
# Assumes:
#  - dstat command is installed

# Command line arguments for primary DStat process.
DSTAT_OPTS="-tcmndrylpg --top-cpu-adv --top-io-adv"

# Command-line arguments for secondary background DStat process.
DSTAT_CSV_OPTS="-tcmndrylpg --output $LOGDIR/dstat-csv.log"

# Execute and background the secondary dstat process and redirect its output.
eval "dstat $DSTAT_CSV_OPTS >& $LOGDIR/dstat-notop.log &"
dstat_csv_pid=$!

# Execute and background the primary dstat process, but keep its output in this
# TTY.
eval "dstat $DSTAT_OPTS &"
dstat_pid=$!

# Catch any exit signals, making sure to also terminate the child dstat
# processes.
function cleanup {
    [[ $dstat_csv_pid ]] && kill $dstat_csv_pid
    [[ $dstat_pid ]] && kill $dstat_pid
}
trap cleanup EXIT

# Keep this script running as long as the child dstat processes are alive.
wait $dstat_csv_pid $dstat_pid
