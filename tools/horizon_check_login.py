#!/usr/bin/python

import urllib
import urllib2
import sys

from cookielib import CookieJar
from HTMLParser import HTMLParser


class InputParser(HTMLParser):

    form_open = False
    data = {}

    def handle_starttag(self, tag, attrs):
        if tag == 'form':
            self.form_open = True
        else:
            if self.form_open:
                if tag == 'input':
                    name = value = ''
                    for k, v in attrs:
                        if k == 'name':
                            name = v
                        if k == 'value':
                            value = v
                    self.data[name] = value

    def handle_endtag(self, tag):
        if tag == 'form' and self.form_open:
            self.form_open = False

    def get_data(self):
        return self.data


class ErrorParser(HTMLParser):

    form_open = False
    error_open = False
    data = ''

    def handle_starttag(self, tag, attrs):
        if tag == 'form':
            self.form_open = True
        elif self.form_open:
                if tag == 'ul':
                    for k, v in attrs:
                        if k == 'class' and v == 'errorlist':
                            self.error_open = True

    def handle_endtag(self, tag):
        if tag == 'form' and self.form_open:
            self.form_open = False
        elif self.error_open and tag == 'ul':
            self.error_open = False

    def handle_data(self, data):
        if self.error_open:
            self.data = data

    def get_data(self):
        return self.data


def set_login_credential(data, username, password):
    data['username'] = username
    data['password'] = password


def my_build_opener():
    cj = CookieJar()
    return urllib2.build_opener(urllib2.HTTPCookieProcessor(cj))

def print_help():
    print "Usage: %s $SERVICE_HOST $USER $PASSWORD" % __file__
    sys.exit(1)
    

def main(argc, argv):

    if argc < 4:
        print_help()

    opener = my_build_opener()

    hostname = argv[1]

    try:
    
        # we expect the login page here
        resp = opener.open('http://%s' % hostname)

        # only if 200 status code means health for the first landing
        if resp.getcode() != 200:
            raise Exception('home page not responding 200')

        html = resp.read()
        resp.close()

        input_parser = InputParser()
        input_parser.feed(html)
        data = input_parser.get_data()

        set_login_credential(data, argv[2], argv[3])

        post_data = urllib.urlencode(data)
        resp = opener.open('http://%s/auth/login/' % hostname, post_data)

        html = resp.read()
        code = resp.getcode()
        resp.close()

        error_parser = ErrorParser()
        error_parser.feed(html)
        err = error_parser.get_data()

        if err:
            raise Exception(err)

        if code == 200:
            # login succeeded, silently quit
            sys.exit(0)
        else:
            raise Exception('unknown error, login failed')

    except Exception as e:
        print e
        sys.exit(1)


if __name__ == '__main__':
    main(len(sys.argv), sys.argv)
