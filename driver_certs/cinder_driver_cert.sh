#!/usr/bin/env bash

# **cinder_cert.sh**

TOP_DIR=`pwd`
source $TOP_DIR/functions
source $TOP_DIR/stackrc
source $TOP_DIR/openrc
TEMPFILE=`mktemp`
RECLONE=True
CINDER_DIR=$DEST/cinder

function log_message() {
    MESSAGE=$1
    STEP_HEADER=$2
	if [[ "$STEP_HEADER" = "True" ]]; then
	    echo -e "\n========================================================" | tee -a $TEMPFILE
	fi
	echo -e `date +%m/%d/%y/%T:`"${MESSAGE}" | tee -a $TEMPFILE
	if [[ "$STEP_HEADER" = "True" ]]; then
	    echo -e "========================================================" | tee -a $TEMPFILE
	fi
}

if [[ "$OFFLINE" = "True" ]]; then
    echo "ERROR: Driver cert requires fresh cone/pull from ${CINDER_BRANCH}"
    echo "       Please set OFFLINE=False and retry."
    exit 1
fi

log_message "RUNNING CINDER DRIVER CERTIFICATION CHECK", True
log_message "Output is being logged to: $TEMPFILE"

cd $CINDER_DIR
log_message "Cloning to ${CINDER_REPO}...", True
log_message `git_clone $CINDER_REPO $CINDER_DIR $CINDER_BRANCH`
setup_develop $CINDER_DIR

log_message "Check Cinder repo status and get latest commit...", True
git status | tee -a $TEMPFILE
git log --pretty=oneline -n 1 | tee -a $TEMPFILE

cd $TOP_DIR
# Verify tempest is installed/enabled
if [[ "$ENABLED_SERVICES" =~ "tempest" ]]; then
    TEMPEST_DIR=$DEST/tempest
    cd $TEMPEST_DIR
    git_clone $TEMPEST_REPO $TEMPEST_DIR $TEMPEST_BRANCH
    setup_develop $TEMPEST_DIR

	log_message "Verify tempest is current....", True
    git status | tee -a $TEMPFILE
    log_message "Check status and get latest commit..."
    git log --pretty=oneline -n 1 | tee -a $TEMPFILE


    #stop and restart cinder services
	log_message "Restart Cinder services...", True
    screen -S stack -p c-api -X stuff $'\003'
    screen -S stack -p c-api -X stuff "cd /opt/stack/cinder && /opt/stack/cinder/bin/cinder-api --config-file /etc/cinder/cinder.conf
	"
    sleep 1

    screen -S stack -p c-sched -X stuff $'\003'
    screen -S stack -p c-sched -X stuff "cd /opt/stack/cinder && /opt/stack/cinder/bin/cinder-scheduler --config-file /etc/cinder/cinder.conf
	"
    sleep 1

    screen -S stack -p c-vol -X stuff $'\003'
    screen -S stack -p c-vol -X stuff "cd /opt/stack/cinder && /opt/stack/cinder/bin/cinder-volume --config-file /etc/cinder/cinder.conf
	"
    sleep 5

    # run tempest api/volume/test_*
	log_message "Run the actual tempest volume tests (run_tests.sh -N tempest.api.volume.test_*)...", True
	exec 2> >(tee -a $TEMPFILE)
    #`./run_tests.sh -N tempest.api.volume.test_*`
    `./run_tests.sh -N tempest.api.volume.test_volumes_list`
	if [[ $? = 0 ]]; then
	    log_message "CONGRATULATIONS!!!  Device driver PASSED!", True
		log_message "Submit output: ($TEMPFILE)"
	else
	    log_message "SORRY!!!  Device driver FAILED!", True
		log_message "Check output in $TEMPFILE"
	fi
	exit 0
else
    log_message "ERROR!!! Cert requires tempest in enabled_services!", True
    log_message"       Please add tempest to enabled_services and retry."
    exit 1
fi
