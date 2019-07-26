import os

import openstack


class KeystoneConfig(object):
    def __init__(self):
        self.users = {}
        self.groups = {}
        self.projects = {}
        self.roles = {}
        self.domains = {}

    def get_or_create_domain(self, name):
        if name not in self.domains:
            domain = self.i.find_domain(name)
            if domain:
                self.domains[name] = domain
            else:
                domain = self.i.create_domain(name=name)
                self.domains[name] = domain

    def get_or_create_project(self, name, domain):
        if name not in self.projects:
            project = self.i.find_project(name)
            if project:
                self.projects[name] = project
            else:
                project = self.i.create_project(name=name, domain_id=domain.id)
                self.projects[name] = project

    def get_or_create_role(self, name):
        if name not in self.roles:
            role = self.i.find_role(name)
            if role:
                self.roles[name] = role
            else:
                role = self.i.create_role(name=name)
                self.roles[name] = role

    def get_or_create_user(self, name, password, domain, email=None):
        if name not in self.users:
            user = self.i.find_user(name)
            if user:
                self.users[name] = user
            else:
                user = self.i.create_user(
                            name=name,
                            password=password,
                            domain_id=domain.id,
                            email=email
                        )
                self.users[name] = user

    def create_service_details(self):
        domain_name = os.environ['SERVICE_DOMAIN_NAME']
        self.get_or_create_domain(domain_name)

        project_name = os.environ['SERVICE_PROJECT_NAME']
        self.get_or_create_project(project_name, self.domains[domain_name])

        # Service role, so service users do not have to be admins
        self.get_or_create_role('service')

        # The ResellerAdmin role is used by Nova and Ceilometer so we need to
        # keep it. The admin role in swift allows a user to act as an admin for
        # their project, but ResellerAdmin is needed for a user to act as any
        # project. The name of this role is also configurable in
        # swift-proxy.conf
        self.get_or_create_role('ResellerAdmin')

        # anotherrole demonstrates that an arbitrary role may be created
        # and used
        # TODO(sleepsonthefloor): show how this can be used for rbac in the
        # future!
        self.get_or_create_role('anotherrole')

    def create_projects(self):
        # invisible project - admin can't see this one
        self.get_or_create_project(
                'invisible_to_admin',
                self.domains['default'],
            )
        # demo
        self.get_or_create_project(
                'demo',
                self.domains['default'],
            )
        password = os.environ['ADMIN_PASSWORD']
        self.get_or_create_user(
                'demo',
                password,
                self.domains['default'],
                'demo@example.com',
            )
        # alt_demo
        self.get_or_create_project(
                'alt_demo',
                self.domains['default'],
            )
        password = os.environ['ADMIN_PASSWORD']
        self.get_or_create_user(
                'alt_demo',
                password,
                self.domains['default'],
                'alt_demo@example.com',
            )

    def get_or_create_group(self, name, domain, description):
        if name not in self.groups:
            group = self.i.find_group(name)
            if group:
                self.groups[name] = group
            else:
                group = self.i.create_group(
                            name=name,
                            domain_id=domain.id,
                            description=description,
                        )
                self.groups[name] = group

    def create_groups(self):
        self.get_or_create_group(
                'admins',
                self.domain['default'],
                'openstack admin group',
            )
        self.get_or_create_group(
                'nonadmins',
                self.domain['default'],
                'non-admin group',
            )

    def check_user_project_role_set(self, user, project, role):
        assignments = self.i.role_assignments_filter(
                            user=user,
                            project=project,
                        )
        for assignment in assignments:
            if assignment.id == role.id:
                return True
        return False

    def set_user_project_roles(self):
        # demo
        if not self.check_user_project_role_set(
                self.users['demo'],
                self.projects['demo'],
                self.roles['member']):
            self.i.assign_project_role_to_user(
                    project=self.projects['demo'],
                    user=self.users['demo'],
                    role=self.roles['member'],
                )
        if not self.check_user_project_role_set(
                self.users['admin'],
                self.projects['demo'],
                self.roles['admin']):
            self.i.assign_project_role_to_user(
                    project=self.projects['demo'],
                    user=self.users['admin'],
                    role=self.roles['admin'],
                )
        if not self.check_user_project_role_set(
                self.users['demo'],
                self.projects['demo'],
                self.roles['anotherrole']):
            self.i.assign_project_role_to_user(
                    project=self.projects['demo'],
                    user=self.users['demo'],
                    role=self.roles['anotherrole'],
                )
        if not self.check_user_project_role_set(
                self.users['demo'],
                self.projects['invisible_to_admin'],
                self.roles['member']):
            self.i.assign_project_role_to_user(
                    project=self.projects['invisible_to_admin'],
                    user=self.users['demo'],
                    role=self.roles['member'],
                )

        # alt_demo
        if not self.check_user_project_role_set(
                self.users['alt_demo'],
                self.projects['alt_demo'],
                self.roles['member']):
            self.i.assign_project_role_to_user(
                    project=self.projects['alt_demo'],
                    user=self.users['alt_demo'],
                    role=self.roles['member'],
                )
        if not self.check_user_project_role_set(
                self.users['admin'],
                self.projects['alt_demo'],
                self.roles['admin']):
            self.i.assign_project_role_to_user(
                    project=self.projects['alt_demo'],
                    user=self.users['admin'],
                    role=self.roles['admin'],
                )
        if not self.check_user_project_role_set(
                self.users['alt_demo'],
                self.projects['alt_demo'],
                self.roles['anotherrole']):
            self.i.assign_project_role_to_user(
                    project=self.projects['alt_demo'],
                    user=self.users['alt_demo'],
                    role=self.roles['anotherrole'],
                )

    def check_group_project_role_set(self, group, project, role):
        assignments = self.i.role_assignments_filter(
                            group=group,
                            project=project,
                        )
        for assignment in assignments:
            if assignment.id == role.id:
                return True
        return False

    def set_group_project_roles(self):
        if not self.check_group_project_role_set(
                self.groups['nonadmin'],
                self.projects['demo'],
                self.roles['member']):
            self.i.assign_project_role_to_user(
                    project=self.projects['demo'],
                    group=self.groups['nonadmin'],
                    role=self.roles['member'],
                )
        if not self.check_group_project_role_set(
                self.groups['nonadmin'],
                self.projects['demo'],
                self.roles['anotherrole']):
            self.i.assign_project_role_to_user(
                    project=self.projects['demo'],
                    group=self.groups['nonadmin'],
                    role=self.roles['anotherrole'],
                )
        if not self.check_group_project_role_set(
                self.groups['nonadmin'],
                self.projects['alt_demo'],
                self.roles['member']):
            self.i.assign_project_role_to_user(
                    project=self.projects['alt_demo'],
                    group=self.groups['nonadmin'],
                    role=self.roles['member'],
                )
        if not self.check_group_project_role_set(
                self.groups['nonadmin'],
                self.projects['alt_demo'],
                self.roles['anotherrole']):
            self.i.assign_project_role_to_user(
                    project=self.projects['alt_demo'],
                    group=self.groups['nonadmin'],
                    role=self.roles['anotherrole'],
                )
        if not self.check_group_project_role_set(
                self.groups['admin'],
                self.projects['admin'],
                self.roles['admin']):
            self.i.assign_project_role_to_user(
                    project=self.projects['admin'],
                    group=self.groups['admin'],
                    role=self.roles['admin'],
                )

    def main(self):
        # Use env vars
        self.conn = openstack.connect()
        self.i = self.conn.identity

        # The keystone bootstrapping process (performed via keystone-manage
        # bootstrap) creates an admin user, admin role, member role, and admin
        # project. As a sanity check we exercise the CLI to retrieve the IDs
        # for these values.
        self.users['admin'] = self.i.find_user('admin', ignore_missing=False)
        self.projects['admin'] = self.i.find_project(
                                    'admin',
                                    ignore_missing=False,
                                )
        self.roles['admin'] = self.i.find_role('admin', ignore_missing=False)
        self.roles['member'] = self.i.find_role('member', ignore_missing=False)
        self.domains['default'] = self.i.find_domain(
                                    'default',
                                    ignore_missing=False,
                                )

        check = self.domains['default'].assign_role_to_user(
                        self.i,
                        self.users['admin'],
                        self.roles['admin'],
                    )
        if not check:
            raise Exception('Assigning admin user to admin role in default '
                            'domain failed')

        self.create_service_details()

        self.create_projects()
        self.set_user_project_roles()

        self.create_groups()
        self.set_group_project_roles()


if __name__ == "__main__":
    keystone_config = KeystoneConfig()
    keystone_config.main()
