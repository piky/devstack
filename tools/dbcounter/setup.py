import setuptools,sys
setuptools.setup(
    name='dbcounter',
    author='Dan Smith',
    author_email='dms@danplanet.com',
    version='0.1',
    descroption='A teeny tiny dbcounter plugin for use with devstack',
    url='http://github.com/openstack/devstack',
    license='Apache',
    enrty_points={
        'sqlalchemy.plugins': ['dbcounter=dbcounter:LogCursorEventsPlugin'],
    },
)
