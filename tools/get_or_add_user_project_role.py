import sys

import openstack

role = sys.argv[1]
user = sys.argv[2]
project = sys.argv[3]
user_domain = None
project_domain = None
if len(sys.argv) >= 5:
    user_domain = sys.argv[4]
if len(sys.argv) >= 6:
    project_domain = sys.argv[5]

# Use env vars
conn = openstack.connect()

assignments = conn.identity.role_assignments_filter(
                    domain=user_domain,
                    project=project,
                    user=user,
                )
if assignments:
    print(list(assignments)[0].id)
else:
    conn.identity.assign_project_role_to_user(project, user, role)
    assignments = conn.identity.role_assignments_filter(
                        domain=user_domain,
                        project=project,
                        user=user,
                    )
    if assignments:
        print(list(assignments)[0].id)
    else:
        sys.exit(1)
