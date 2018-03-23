# Writing Tasks

> **Difficulty**: Basic

> **Time**: Approximately 15 minutes

In this exercise you will write your first Puppet Tasks for use with `bolt`.

- [How do tasks work?](#how-do-tasks-work)
- [Write your first task in Bash](#write-your-first-task-in-bash)
- [Write your first task in PowerShell](#write-your-first-task-in-powershell)
- [Write your first task in Python](#write-your-first-task-in-python)

# Prerequisites

For the following exercises you should already have `bolt` installed and have a few nodes (either Windows or Linux) available to run commands against. The following guides will help:

1. [Installing Bolt](../1-installing-bolt)
1. [Acquiring nodes](../2-acquiring-nodes)

It is also useful to have some familiarity with running commands with `bolt` so you understand passing nodes and credentials. The following exercise is recommended:

1. [Running Commands](../3-running-commands)


# How do tasks work?

Tasks allow you to share commonly used commands as Puppet modules. This means they can be uploaded and downloaded from the Forge, as well as managed using all the existing Puppet tools. You can also just use them from GitHub or as a way of organizing regularly used commands locally.

By default tasks take arguments as environment variables, prefixed with `PT` (short for Puppet Tasks). Tasks are stored in the `tasks` directory of a module, a module being a directory with a unique name. You can have several tasks per module, but the `init` task is special and will be run by default if a task name is not specified. All of that will make more sense if we see it in action.

Note that tasks can be implemented in any language which will run on the target nodes.


# Write your first task in Bash

For our first example we'll use `sh` here purely as a simple demonstration, but you could use Perl, Python, Lua, JavaScript, etc. as long as it can read environment variables or take content on stdin.

Save the following file to `modules/exercise5/tasks/init.sh`:

```
#!/bin/sh

echo $(hostname) received the message: $PT_message
```

We can then run that task using `bolt`. Note the `message` argument. This will be expanded to the `PT_message` environment variable expected by our task. By naming parameters explictly it's easier for others to use your tasks.

```
bolt task run exercise5 message=hello --nodes $NODE --modulepath ./modules
```

This should result in output similar to:

```
Started on node1...
Finished on node1:
  localhost.localdomain received the message: hello
Ran on 1 node in 0.43 seconds
```

Try running the `bolt` command with a different value for `message` and you should see the expected results.


# Write your first task in PowerShell

If you're targeting Windows nodes then you might prefer to implement the task in PowerShell. Let's save the following file as `modules/exercise5/tasks/print.ps1`

```powershell
Write-Output "$env:computername received the message: $env:PT_message"
```

We can then run it via `bolt` on our remote nodes with the following:

```
bolt task run exercise5::print message="hello powershell" --nodes $WINNODE --modulepath ./modules
```

Note:

* The name of the file on disk (minus any file extension) translates to the name of the task when run via `bolt`, in this case `print`
* The name of the module/directory is also used to find the relevant task, in this case `exercise5`
* As with the Bash example above, we name parameters so that they're more easily understood by users of the task

# Write your first task in Python

The above examples are obviously very simple. Lets implement something slightly more interesting and useful. We'll use Python for this example but remember Puppet Tasks can be implemented in any language which can be run on the target node. When using a more fully featured language like python tasks can return structured data by printing a single JSON object to stdout.

Note that `bolt` assumes that the required runtime is already available on the target nodes. So for the following examples to work the target nodes should have Python 2 or 3 already installed. This task will also work on Windows system with Python 2 or 3 installed on them.

Save the following as `modules/exercise5/tasks/gethost.py`:

```python
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
```

We can then run the task against our nodes like so:

```
$ bolt task run exercise5::gethost host=google.com --nodes $NODE --modulepath ./modules
Started on node1...
Finished on node1:
  google.com is available at 216.58.204.14 on localhost.localdomain
  {
    "host": "google.com",
    "hostname": "localhost.localdomain",
    "ipaddr": "216.58.204.14"
  }
Ran on 1 node in 0.41 seconds
```

The important thing to note above is that our task is just a standard Python script, in this case using parts of the Python standard library. Apart from accepting arguments as `PT_`-prefixed environment variables, which will work outside Puppet Tasks too, the script is exactly what you would write to achieve the same task outside Puppet Tasks. `bolt` just gives you the ability to run that script across a large number of nodes quickly and easily. No configuration files or rewriting
required.

# Next steps

Now that you know how to write tasks you can move on to:

1. [Downloading and running existing tasks](../6-downloading-and-running-existing-tasks)
