#!/bin/bash -ex

(
declare -A plugins

test -r data/devstack-plugins-registry.header && cat data/devstack-plugins-registry.header

pushd ${git_dir:-/opt/openstack} >/dev/null
for i in *
do
    pushd ${i} >/dev/null
    if output="$(git log --diff-filter=A --format='%cd' --date=short -1 -- devstack/plugin.sh)"; then
        test -n "$output" && plugins[$i]=${output}
    fi
    popd >/dev/null
done
popd >/dev/null

sorted_plugins=( $(for k in "${!plugins[@]}"; do echo "$k"; done | sort))

for k in "${sorted_plugins[@]}"
do
    project=${k:0:18}
    giturl="git://git.openstack.org/openstack/${k:0:26}"
    pdate="${plugins[$k]}"
    printf "|%-18s|%-60s|%-12s|\n" "${project}" "${giturl}" "${pdate}"
    printf "+------------------+------------------------------------------------------------+------------+\n"
done

test -r data/devstack-plugins-registry.footer && cat data/devstack-plugins-registry.footer
) > doc/source/plugin-registry.rst
