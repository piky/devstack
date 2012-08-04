#!/bin/python
# vim: tabstop=4 shiftwidth=4 softtabstop=4
#
# Copyright 2012,  Nachi Ueno,  NTT MCL,  Inc.
# All Rights Reserved.
#
#    Licensed under the Apache License,  Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing,  software
#    distributed under the License is distributed on an "AS IS" BASIS,  WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND,  either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

import os
import sys
import logging

from sqlalchemy.ext import sqlsoup
from subprocess import call
from quantum.agent.linux import interface
from quantum.agent.common import config
from quantumclient.v2_0 import client
from quantum.openstack.common import importutils
from quantum.openstack.common import cfg
from quantum.agent.linux import interface
from quantum.agent.linux import ip_lib

logging.basicConfig()
LOG = logging.getLogger('test-agent')
#TODO (nati) get verbose option
LOG.setLevel(logging.WARN)


def env(key, default=None):
    return os.environ.get(key, default)


class QuantumTestAgent():
    OPTS = [
        cfg.StrOpt('root_helper', default='sudo'),
        cfg.StrOpt('db_connection', default=''),
        cfg.StrOpt('admin_user'),
        cfg.StrOpt('admin_password'),
        cfg.StrOpt('admin_tenant_name'),
        cfg.StrOpt('auth_url'),
        cfg.StrOpt('auth_strategy', default='keystone'),
        cfg.StrOpt('auth_region'),
        cfg.StrOpt('interface_driver',
                   help="The driver used to manage the virtual interface.")
    ]

    def setup(self, network, port):
        interface_name = self.get_interface_name(port)
        self.fault = False
        if ip_lib.device_exists(interface_name):
            LOG.debug(_('Reusing existing device: %s.') % interface_name)
        else:
            self.driver.plug(network.id,
                             port.id,
                             interface_name,
                             port.mac_address)
        self.driver.init_l3(port, interface_name)

    def destroy(self, port):
        quantum = self.get_quantum_client()
        self.driver.unplug(self.get_interface_name(port))
        quantum.delete_port(port.id)

    def get_interface_name(self, port):
        return self.driver.get_device_name(port)

    def is_success(self):
        return not self.fault

    def ping(self, network_id, ip_address):
        #TODO (nati)_nampespace support
        ret = os.system('ping -c 1 %s' % ip_address)
        if ret != 0:
            self.fault = True
            LOG.error("Can't ping to %s in %s" % (ip_address, network_id))
            return
        LOG.info("Ping OK to %s in %s" % (ip_address, network_id))

    def test_connection(self, network):
        port = self._create_port(network)
        self.setup(network, port)
        quantum_client = self.get_quantum_client()
        ports = quantum_client.list_ports(network_id=network.id)
        for port_dict in ports['ports']:
            for fixed_ips in port_dict['fixed_ips']:
                ip_address = fixed_ips['ip_address']
                self.ping(network.id, ip_address)
        self.destroy(port)

    def test_connection_all_network(self):
        for network_in_db in self.db.networks.all():
            network = AugmentingWrapper(
                self.db.networks.filter_by(id=network_in_db.id).one(),
                self.db
            )
            self.test_connection(network)

    def __init__(self, conf):
        self.conf = conf
        self.db = sqlsoup.SqlSoup(self.conf.db_connection)
        LOG.info("Connecting to database \"%s\" on %s" %
                 (self.db.engine.url.database,
                  self.db.engine.url.host))
        if not conf.interface_driver:
            LOG.error(_('You must specify an interface driver'))
        self.driver = importutils.import_object(conf.interface_driver, conf)

    def get_quantum_client(self):
        quantum_client = client.Client(
            username=self.conf.admin_user,
            password=self.conf.admin_password,
            tenant_name=self.conf.admin_tenant_name,
            auth_url=self.conf.auth_url,
            auth_strategy=self.conf.auth_strategy,
            auth_region=self.conf.auth_region
        )
        return quantum_client

    def _create_port(self, network):
        # todo (mark): reimplement using RPC
        # Usage of client lib is a temporary measure.
        quantum = self.get_quantum_client()

        body = dict(port=dict(
            admin_state_up=True,
            network_id=network.id,
            device_id='test-agent',
            tenant_id=network.tenant_id,
            fixed_ips=[dict(subnet_id=s.id) for s in network.subnets]))
        port_dict = quantum.create_port(body)['port']
        self.db.commit()

        port = AugmentingWrapper(
            self.db.ports.filter_by(id=port_dict['id']).one(),
            self.db)
        return port


class AugmentingWrapper(object):
    """A wrapper that augments Sqlsoup results so that they look like the
    base v2 db model.
    """

    MAPPING = {
        'networks': {'subnets': 'subnets', 'ports': 'ports'},
        'subnets': {'allocations': 'ipallocations'},
        'ports': {'fixed_ips': 'ipallocations'},

    }

    def __init__(self, obj, db):
        self.obj = obj
        self.db = db

    def __repr__(self):
        return repr(self.obj)

    def __getattr__(self, name):
        """Executes a dynamic lookup of attributes to make SqlSoup results
        mimic the same structure as the v2 db models.

        The actual models could not be used because they're dependent on the
        plugin and the agent is not tied to any plugin structure.

        If .subnet, is accessed, the wrapper will return a subnet
        object if this instance has a subnet_id attribute.

        If the _id attribute does not exists then wrapper will check MAPPING
        to see if a reverse relationship exists.  If so, a wrapped result set
        will be returned.
        """

        try:
            return getattr(self.obj, name)
        except:
            pass

        id_attr = '%s_id' % name
        if hasattr(self.obj, id_attr):
            args = {'id': getattr(self.obj, id_attr)}
            return AugmentingWrapper(
                getattr(self.db, '%ss' % name).filter_by(**args).one(),
                self.db
            )
        try:
            attr_name = self.MAPPING[self.obj._table.name][name]
            arg_name = '%s_id' % self.obj._table.name[:-1]
            args = {arg_name: self.obj.id}

            return [AugmentingWrapper(o, self.db) for o in
                    getattr(self.db, attr_name).filter_by(**args).all()]
        except KeyError:
            pass

        raise AttributeError


def main():
    conf = config.setup_conf()
    conf.register_opts(QuantumTestAgent.OPTS)
    conf.register_opts(interface.OPTS)
    conf(sys.argv)
    config.setup_logging(conf)
    test_agent = QuantumTestAgent(conf)
    LOG.info("Test agent tests connections for all network fixed_ip")
    test_agent.test_connection_all_network()
    if not test_agent.is_success():
        log.error('some error occured. Failed to check')
        sys.exit(1)
    sys.exit(0)

if __name__ == '__main__':
    main()
