from oslo_config import cfg
from oslo_log import log as logging
from paste import deploy

from nova import config
from nova import objects
from nova import service  # noqa
from nova import utils

CONF = cfg.CONF

config_files = ['/etc/nova/api-paste.ini', '/etc/nova/nova.conf']
config.parse_args([], default_config_files=config_files)

LOG = logging.getLogger(__name__)
logging.setup(CONF, "nova")
utils.monkey_patch()
objects.register_all()

conf = config_files[0]
name = "ec2"

options = deploy.appconfig('config:%s' % conf, name=name)

application = deploy.loadapp('config:%s' % conf, name=name)
