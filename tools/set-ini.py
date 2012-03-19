#!/usr/bin/env python
#
# set-ini.py --config-file <config-file>
#           [--set <section> <attribute> <value> [--set ... ]]
#           [--delete <section> <attribute> [--delete ... ]]
#
# Multiple --set and --delete options can be given to perform multiple operations
# on a single pass over the config-file.
#
# Based on justinsb's https://github.com/justinsb/openstack-simple-config/blob/master/utils/openstack-config-set
#
# vim: tabstop=4 shiftwidth=4 softtabstop=4

import argparse
import ConfigParser
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--config-file', metavar='<config-file>',
                    help='Configuration file to edit')
parser.add_argument('--delete', nargs=2,
                    action='append',
                    metavar=('<section>', '<attribute>'),
                    help='Delete an attribute from the named section')
parser.add_argument('--set', nargs=3,
                    action='append',
                    metavar=('<section>', '<attribute>', '<value>'),
                    help='Set the attribute in the named section')
args = parser.parse_args()

config = ConfigParser.ConfigParser()
config.read(args.config_file)

# Do deletes first so settings in a deleted section survive
if args.delete:
    for (section, attribute) in args.delete:
        if not config.has_section(section):
            continue

        config.remove_option(section, attribute)

if args.setting:
    for (section, attribute, value) in args.setting:
        if not config.has_section(section):
            config.add_section(section)

        config.set(section, attribute, value)

with open(args.config_file, 'w') as config_file:
    config.write(config_file)
