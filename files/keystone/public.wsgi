import os

from paste import deploy

from keystone.common import logging
from keystone import config
from keystone.openstack.common import gettextutils

gettextutils.install('keystone')

logger = logging.getLogger(__name__)

CONF = config.CONF
CONF(project='keystone')

if CONF.debug:
    CONF.log_opt_values(logging.getLogger(CONF.prog), logging.DEBUG)

application = deploy.loadapp('config:%s' % config.find_paste_config(), name='main')
