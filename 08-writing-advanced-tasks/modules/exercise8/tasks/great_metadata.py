#!/usr/bin/env python

"""
This script prints the values and types passed to it via standard in.  It will
return a JSON string with a parameters key containing objects that describe
the parameters passed by the user.
"""

import json
import sys

def make_serializable(object):
  if sys.version_info[0] > 2:
    return object
  if isinstance(object, unicode):
    return object.encode('utf-8')
  else:
    return object

data = json.load(sys.stdin)

message = """
Congratulations on writing your metadata!  Here are
the keys and the values that you passed to this task.
"""

result = {'message': message, 'parameters': []}
for key in data:
    k = make_serializable(key)
    v = make_serializable(data[key])
    t = type(data[key]).__name__
    param = {'key': k, 'value': v, 'type': t}
    result['parameters'].append(param)

print(json.dumps(result))

