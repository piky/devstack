#!/usr/bin/env python2

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

import datetime
import sys

import subunit
from subunit import iso8601

start_time = datetime.datetime.fromtimestamp(float(sys.argv[1])).replace(
    tzinfo=iso8601.UTC)
elapsed_time = datetime.timedelta(seconds=int(sys.argv[2]))
stop_time = start_time + elapsed_time

if len(sys.argv) > 3:
    status = sys.argv[3]
else:
    status = 'success'

if len(sys.argv) > 4:
    test_id = sys.argv[4]
else:
    test_id = 'devstack'


kwargs = {}
# Write the subunit stream
output = subunit.v2.StreamResultToBytes(sys.stdout)
output.startTestRun()
kwargs['timestamp'] = start_time
kwargs['test_id'] = test_id
output.status(**kwargs)
# Write the end of the test
kwargs['test_status'] = status
kwargs['timestamp'] = stop_time
output.status(**kwargs)
output.stopTestRun()
