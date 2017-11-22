# Copyright (C) 2017 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import shutil
import tempfile
import unittest

from devstack_local_conf import LocalConf
from collections import OrderedDict

class TestDevstackLocalConf(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_plugin_deps(self):
        localrc = {'test_localrc': '1'}
        local_conf = {'install':
                      {'nova.conf':
                       {'main':
                        {'test_conf': '2'}}}}
        services = {'cinder': True}
        # We use ordereddict here to make sure the plugins are in the
        # *wrong* order for testing.
        plugins = OrderedDict([
            ('bar', 'git://git.openstack.org/openstack/bar-plugin'),
            ('foo', 'git://git.openstack.org/openstack/foo-plugin'),
            ('baz', 'git://git.openstack.org/openstack/baz-plugin'),
            ])
        p = dict(localrc=localrc,
                 local_conf=local_conf,
                 base_services=[],
                 services=services,
                 plugins=plugins,
                 base_dir='./test',
                 path=os.path.join(self.tmpdir, 'test.local.conf'))
        lc = LocalConf(p.get('localrc'),
                       p.get('local_conf'),
                       p.get('base_services'),
                       p.get('services'),
                       p.get('plugins'),
                       p.get('base_dir'))
        lc.write(p['path'])

        plugins = []
        with open(p['path']) as f:
            for line in f:
                if line.startswith('enable_plugin'):
                    plugins.append(line.split()[1])
        self.assertEqual(['bar', 'baz', 'foo'], plugins)

if __name__ == '__main__':
    unittest.main()
