#!/usr/bin/env python

import socket
import os

host = os.environ.get('PT_host')

if host:
    print("%s is available at %s on %s" % (host, socket.gethostbyname(host), socket.gethostname()))
else:
    print('No host argument passed')
