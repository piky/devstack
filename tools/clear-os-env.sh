# Clear openstack access envirnonment variables
#

envs=`env | grep -e '^OS_' | cut -d= -f 1`
for env_item in $envs; do
    echo ${env_item}
	export -n ${env_item}
done
