# Clear openstack access envirnonment variables
# To run this script use "source clear-os-env.sh"

envs=`env | grep -e '^OS_' | cut -d= -f 1`
for env_item in $envs; do
    echo ${env_item}
    export -n ${env_item}
done
