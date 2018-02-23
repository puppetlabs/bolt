# Writing advanced tasks

> **Difficulty**: Intermediate

> **Time**: Approximately 10 minutes

In this exercise you will write a task with metadata. Including a task that supports_noop.

# Prerequisites

For the following exercises you should already have `bolt` installed and have a few nodes (either Windows or Linux) available to run commands against. The following guides will help:

1. [Installing Bolt](../1-installing-bolt)
1. [Acquiring nodes](../2-acquiring-nodes)
1. [Writing tasks](../5-writing-tasks)

# Writing your first task with metadata

Writing metadata helps those that consume your tasks know how to provide input to the tasks that you write.  Metadata for a task is written in JSON and is expected to have the same name as your task with a `.json` extension. So if you write a task called `foo_bar.py` you should write a corresponding `foo_bar.json`.  Lets start by writing a simple task that formats the parameters a user gives it.

Save the following file to `modules/exercise8/tasks/great_metadata.py`:
```
#! /usr/bin/env python

"""
This script prints the values and types passed to it via standard in.  It will
return a JSON string with a parameters key containing objects that describe
the parameters passed by the user.
"""

import json
import sys

def make_serializable(object):
  if isinstance(object, unicode):
    return object.encode('utf-8')
  else:
    return object

data = json.load(sys.stdin)

message = "Congratulations on writing your metadata!  Here are the keys and the values that you passed to this task."

result = {'message': message, 'parameters': []}
for key in data:
    k = make_serializable(key)
    v = make_serializable(data[key])
    t = type(data[key]).__name__
    param = {'key': k, 'value': v, 'type': t}
    result['parameters'].append(param)

print(json.dumps(result))
```

Now lets write the accompanying metadata.  Well specify the parameters as types such as `"type": "Integer"`  which will help us validate the users input as an `Integer`.  Save the following file to `modules/exercise8/tasks/great_metadata.json`:
```
{
  "description": "An exercise in writing great metadata",
  "input_method": "stdin",

  "parameters": {
    "name": {
      "description": "The description for the 'name' parameter",
      "type": "String"
    },
    "recursive": {
      "description": "The description for the 'recursive' parameter",
      "type": "Boolean"
    },
    "action": {
      "description": "The description for the 'action' parameter",
      "type": "Enum[stop, start, restart]"
    },
    "timeout": {
      "description": "The description for the 'timeout' parameter",
      "type": "Optional[Integer]"
    }
  }
}
```

# Using your task with metadata

Use the following command to show to test that your task is listed with its description.

```
$ bolt task show --modulepath ./modules
...
exercise8::great_metadata     An exercise in writing great metadata
facter_task                   Inspect the value of system facts
install_puppet                Install the puppet 5 agent package
...
```


Now use the bolt task show command to inspect the parameters used by your task.  This will show you the parameters with descriptions and expected type.

```
$ bolt task show exercise8::great_metadata --modulepath ./modules
exercie8::great_metadata - An exercise in writing great metadata

USAGE:
bolt task run --nodes, -n <node-name> exercise8::great_metadata name=<value> [user=<value>] password=<value> action=<value>

PARAMETERS:
- name: String
    The description for the 'name' parameter
- recursive: Boolean
    The description for the 'password' parameter
- action: Enum['restart', 'start', 'stop']
    The description for the 'action' parameter
- timeout: Optional[Integer]
    The description for the 'timeout' parameter
```

# Testing our task's metadata validation

Bolt can use the types that you have specified in your metadata to validate parameters passed to your task.  Lets attempt to run your task with an incorrect value passed to the `action` parameter.  We will pass the params as a JSON string.

```
$ bolt task run exercise8::great_metadata --nodes all --modulepath ./modules --params '{"name":"poppey","action":"spinach","recursive":true}'
Task exercise8::great_metadata:
 parameter 'action' expects a match for Enum['restart', 'start', 'stop'], got 'spinach'
```

If we correct our mistake we can see the task working correctly
```
$ bolt task run exercise8::great_metadata --nodes all --modulepath ./modules --params '{"name":"poppey","action":"start","recursive":true}'

  {
    "message": "Congratulations on writing your metadata!  Here are the keys and the values that you passed to this task.",
    "parameters": [
      {
        "type": "unicode",
        "value": "start",
        "key": "action"
      },
      {
        "type": "unicode",
        "value": "poppey",
        "key": "name"
      },
      {
        "type": "bool",
        "value": true,
        "key": "recursive"
      }
    ]
  }
Ran on 1 node in 0.73 seconds
```

# Making your task support noop

Tasks can be written to support noop. Lets create a new task that supports the `--noop` feature.  First lets create the metadata for our new task. Save the following file to `modules/exercise8/tasks/file.json`:
```
{
  "description": "Write content to a file.",
  "supports_noop": true,
  "parameters": {
    "filename": {
      "description": "the file to write to",
      "type": "String[1]"
    },
    "content": {
      "description": "The content to write",
      "type": "String"
    }
  }
}
```

Next we need to make a task that respond to the noop input. Our task will use input from stdin, when a user passes the `--noop` flag the JSON object from stdin will contain the `_noop` key with a value of True.  Save the following file to `modules/exercise8/tasks/file.py`:

```
#!/usr/bin/env python

"""
This script attempts the creation of a file on a target system. It will
return JSON string describing the actions it performed.  If passed "{"_noop": True}"
on stdin it will check to see if it can write the file but not actually write it.
"""

import json
import os
import sys

params = json.load(sys.stdin)
filename = params['filename']
content = params['content']
noop = params.get('_noop', False)

exitcode = 0

def make_error(msg):
  error = {
      "_error": {
          "kind": "file_error",
          "msg": msg,
          "details": {},
      }
  }
  return error

try:
  if noop:
    path = os.path.abspath(os.path.join(filename, os.pardir))
    file_exists = os.access(filename, os.F_OK)
    file_writable = os.access(filename, os.W_OK)
    path_writable = os.access(path, os.W_OK)

    if path_writable == False:
      exitcode = 1
      result = make_error("Path %s is not writable" % path)
    elif file_exists == True and file_writable == False:
      exitcode = 1
      result = make_error("File %s is not writable" % filename)
    else:
      result = { "success": True , '_noop': True }
  else:
    with open(filename, 'w') as fh:
      fh.write(content)
      result = { "success": True }
except Exception as e:
  exitcode = 1
  result = make_error("Could not open file %s: %s" % (filename, str(e)))
print(json.dumps(result))
exit(exitcode)

```

Lets test out our new task with the `--noop` flag.
```
$ bolt task run exercise8::file --nodes all --modulepath ./modules content=Hello_World filename=/tmp/hello_world --noop
  {
    "_noop": true,
    "success": true
  }
Ran on 1 node in 0.64 seconds
```

Now if we run again without `--noop` we can see the task creating the file successfully.
```
$ bolt task run exercise8::file --nodes all --modulepath ./modules content=Hello_World filename=/tmp/hello_world
  {
    "success": true
  }
Ran on 1 node in 0.63 second
```
# Next steps

Now that you know how to use `--noop` and write metadata you can move on to:

1. [Writing advanced Plans](../9-writing-advanced-plans)
