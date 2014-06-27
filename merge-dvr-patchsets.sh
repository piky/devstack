#!/bin/bash

gerrit_remote=gerrit
gerrit_user=john-doe
gerrit_repo=openstack/neutron
gerrit_ssh=review.openstack.org:29418
gerrit_url="ssh://${gerrit_user}@${gerrit_ssh}/${gerrit_repo}.git"

git remote add $gerrit_remote $gerrit_url 2>/dev/null || true

# set user, host, port, and project from git config
eval $(echo "$(git config remote.$gerrit_remote.url)" |
    sed 's,ssh://\(.*\)@\(.*\):\([[:digit:]]*\)/\(.*\).git,user=\1 host=\2 port=\3 project=\4,')

gerrit() {
    ssh $user@$host -p $port gerrit ${1+"$@"}
}

get_patchset_information() {
    eval $(gerrit query --current-patch-set --dependencies $1 |
        awk '
            BEGIN {
                mode="main"
                printf "dependsOn=()\n"
            }
            / currentPatchSet:/ { mode="currentPatchSet" }
            / dependsOn:/ { mode="dependsOn" }
            / neededBy:/ { mode="neededBy" }
            / ref:/ {
                if (mode=="currentPatchSet") {
                    printf "new_patch_ref=%s\n", $2
                }
            }
            / open:/ { printf "open=%s\n", $2 }
            / revision:/ {
                if (mode=="currentPatchSet") {
                    printf "revision=%s\n", $2
                }
            }
            / number:/ {
                if (mode=="main") {
                    printf "review_num=%s\n", $2
                }
                if (mode=="currentPatchSet") {
                    printf "new_patchset=%s\n", $2
                }
                if (mode=="dependsOn") {
                    printf "dependsOn+=(%s)\n", $2
                }
            }
        ')
}

edges=()
for arg in "$@"
do
    get_patchset_information $arg

    if [ "$open" != "true" ]
    then
        echo >&2 "Skipping $arg because it is closed"
        continue
    fi

    git fetch $gerrit_remote $new_patch_ref

    # Organize dependencies
    for dependency in "${dependsOn[@]}"
    do
        get_patchset_information $dependency
        [ "$open" = "true" ] && edges+=($arg $dependency)
    done
done

# Topologically sort the patches
sorted=($(for edge in "${edges[@]}"
do
    echo $edge
done | tsort | tac))

revisions=()

# Check out the base patch
get_patchset_information ${sorted[0]}
revisions+=($revision)
unset sorted[0]
git checkout $revision

echo "${sorted[@]}"

for ref in "${sorted[@]}"
do
    get_patchset_information $ref
    revisions+=($revision)
    git cherry-pick --no-commit $revision
    if [ $? -ne 0 ]
    then
        echo "Fix er up"
        bash
    fi
done

tree=$(git write-tree)
commit=$(git commit-tree -m "Merge DVR patches together" \
         $(for rev in ${revisions[@]}; do echo -p $rev; done) \
         $tree)
git checkout $commit
