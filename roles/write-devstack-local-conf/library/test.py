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

from local_conf import LocalConf


def main():
    localrc = {'test_localrc': '1'}
    local_conf = {'install':
                  {'nova.conf':
                   {'main':
                    {'test_conf': '2'}}}}
    services = {'cinder': True}
    plugins = {'shade': 'git://git.openstack.org/openstack-infra/shade'}
    p = dict(localrc=localrc,
             local_conf=local_conf,
             services=services,
             plugins=plugins,
             path='/tmp/test.local.conf')
    lc = LocalConf(p.get('localrc'),
                   p.get('local_conf'),
                   p.get('services'),
                   p.get('plugins'),
                   p.get('src_root'))
    lc.write(p['path'])


if __name__ == '__main__':
    main()
