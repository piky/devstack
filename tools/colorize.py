#!/usr/bin/env python


import fileinput
import re

from colored import fg, bg, attr

REQUEST_ID = '(req-\w{8}-\w{4}-\w{4}-\w{4}-\w{12})'
DATEFMT = '\w+ \d+ \d+:\d+:\d+(\.\d{3.6})?'
STATUSFMT = '(DEBUG|INFO|WARNING|ERROR|TRACE|AUDIT)'
LINE = '^(?P<date>%s) (?P<host>\S+) (?P<process>\S+)\: (?P<level>%s)' % \
       (DATEFMT, STATUSFMT)

LINERE = re.compile(LINE)

LEVEL_COLORS = {
    'DEBUG': fg('grey_50'),
}


def request_id(line, line_color):
    m = re.search(REQUEST_ID, line)
    if not m:
        return line

    line_color = line_color or attr('reset')
    req = m.group(1)
    color = int(req[-2:], 16)
    line = re.sub(REQUEST_ID, fg(color) + req + line_color, line)
    return line


def status_color(line, level):
    if level in LEVEL_COLORS:
        return LEVEL_COLORS[level] + line + attr('reset'), LEVEL_COLORS[level]
    return line, None


for line in fileinput.input():
    line = line.rstrip()
    m = LINERE.match(line)
    if m:
        line, color = status_color(line, m.group('level'))
        line = request_id(line, color)

    print(line)
