import sys

import openstack

role_string = sys.argv[1]
user_string = sys.argv[2]
project_string = sys.argv[3]
user_domain = None
project_domain = None

if len(sys.argv) >= 5:
    user_domain = sys.argv[4]
if len(sys.argv) >= 6:
    project_domain = sys.argv[5]

# Use env vars
conn = openstack.connect(
            user_domain_name=user_domain,
            project_domain_name=project_domain,
        )

# Get all the resource data whether provided an id or name
role = conn.identity.find_role(role_string)
if not role:
    sys.exit(1)
user = conn.identity.find_user(user_string)
if not user:
    sys.exit(2)
project = conn.identity.find_user(project_string)
if not project:
    sys.exit(3)

# Check if role assignment already in place
gen_assignments = conn.identity.role_assignments_filter(
                        project=project,
                        user=user,
                    )
assignments = list(gen_assignments)
if assignments:
    for assignment in assignments:
        if assignment.id == role.id:
            print(assignment.id)
            sys.exit(0)

# Not already in place: Add it
conn.identity.assign_project_role_to_user(project, user, role)
gen_assignments = conn.identity.role_assignments_filter(
                        project=project,
                        user=user,
                    )
assignments = list(gen_assignments)
if assignments:
    for assignment in assignments:
        if assignment.id == role.id:
            print(assignment.id)
            sys.exit(0)
else:
    # No assignments found
    sys.exit(4)

# No matching assignments found
sys.exit(5)
