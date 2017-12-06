#!/usr/bin/env python

import socket
import sys
import os
import json

host = os.environ.get('PT_host')
result = { 'host': host }

if host:
    result['ipaddr'] = socket.gethostbyname(host)
    result['hostname'] = socket.gethostname()
    # The _output key is special and used by bolt to display a human readable summary
    result['_output'] = "%s is available at %s on %s" % (host, result['ipaddr'], result['hostname'])
    print(json.dumps(result))
else:
    # The _error key is special. Bolt will print the 'msg' in the error for the user.
    result['_error'] = { 'msg': 'No host argument passed', 'kind': 'exercise5/missing_parameter' }
    print(json.dumps(result))
    sys.exit(1)
