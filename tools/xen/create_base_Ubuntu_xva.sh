#/bin/bash

# run on XenServer to create a Ubuntu base xva from the raw Ubuntu template.

set -o errexit
set -o nounset
set -o xtrace

TEMP=`getopt -o j:p: --long journal:,path: -- "$@"`
eval set -- "$TEMP"
while true ; do
    case "$1" in
        -j|--journal) JOURNAL=$2; shift 2 ;;
        -p|--path)   XVA_PATH=$2; shift 2 ;;
        --) shift; break ;;
        *) echo "Error: invalid parameter!"; exit 1 ;;
    esac
done

if [ -z "$XVA_PATH" ]; then
    echo "Error: please specify the path to save xva file"
    exit 1
fi

GUEST_NAME=devstack
TNAME="jeos_template_for_devstack"
THIS_DIR=$(cd $(dirname "$0") && pwd)

function wait_for_VM_to_halt {
    set +x
    echo "Waiting for the VM to halt."
    while true; do
        state=$(xe vm-list name-label="$GUEST_NAME" power-state=halted)
        if [ -n "$state" ]; then
            break
        else
            echo -n "."
            sleep 20
        fi
    done
    set -x
}

vm_uuid=$(xe vm-install template="$TNAME" new-name-label="$GUEST_NAME")

#
# Prepare VM for DevStack
#
xe vm-param-set other-config:os-vpx=true uuid="$vm_uuid"

# Install XenServer tools, and other such things
$THIS_DIR/prepare_guest_template.sh "$GUEST_NAME"

# start the VM to run the prepare steps
xe vm-start vm="$GUEST_NAME"

# Wait for prep script to finish and shutdown system
wait_for_VM_to_halt

# Disable FS journaling.
if [ "$JOURNAL" = "disable" ]; then
    vm_vbd=$(xe vbd-list vm-uuid=$vm_uuid --minimal)
    vm_vdi=$(xe vdi-list vbd-uuids=$vm_vbd --minimal)
    dom_zero_uuid=$(xe vm-list dom-id=0 --minimal)
    #tmp_vbd=$(xe vbd-create device=autodetect bootable=false mode=RW type=Disk  vdi-uuid=$vm_vdi vm-uuid=$dom_zero_uuid)
    tmp_vbd=$(xe vbd-create vm-uuid=$dom_zero_uuid vdi-uuid=$vm_vdi device=autodetect)
    xe vbd-plug uuid=$tmp_vbd
    pool_Id=$(xe pool-list minimal=true)
    sr_id=$(xe pool-param-get param-name=default-SR uuid=$pool_Id)
    kpartx -p p -avs  /dev/sm/backend/$sr_id/$vm_vdi
    tune2fs -l  /dev/mapper/${vm_vdi}p1 | grep "Filesystem features"
    tune2fs -O ^has_journal /dev/mapper/${vm_vdi}p1
    tune2fs -l  /dev/mapper/${vm_vdi}p1 | grep "Filesystem features"
    kpartx -dv  /dev/sm/backend/$sr_id/$vm_vdi
    xe vbd-unplug uuid=$tmp_vbd timeout=60 || echo "the command od \"xe vbd-unplug uuid=$tmp_vbd timeout=600\" failed with RET=$?"
    xe vbd-destroy uuid=$tmp_vbd
fi

# export xva
xe vm-export filename=${XVA_PATH}/devstack.xva vm="$GUEST_NAME" compress=true

echo "Finished XVA generation. Please find the file from: ${XVA_PATH}/devstack.xva\n"
