# Writing Tasks

> **Difficulty**: Basic

> **Time**: Approximately 15 minutes

In this lab you will write your first Puppet Tasks for use with `bolt`.

- [Write your first task in Bash](#write-your-first-task-in-bash)
- [Write your first task in PowerShell](#write-your-first-task-in-powershell)
- [Write your first task in Python](#write-your-first-task-in-python)

# Prerequisites

For the following exercises you should already have `bolt` installed and have a few nodes (either Windows or Linux) available to run commands against. The following guides will help:

1. [Installing Bolt](../1-installing-bolt)
1. [Acquiring nodes](../2-acquiring-nodes)

It is also useful to have some familiarity with running commands with `bolt` so you understand passing nodes and credentials. The following lab is recommended:

1. [Running Commands](../3-running-commands)

# Write your first task in Bash 

Tasks allow you to share commonly used commands as Puppet modules. This means they can be uploaded and downloaded from the Forge, as well as managed using all the existing Puppet tools. You can also just use them from GitHub or as a way of organizing regularly used commands locally. 

By default tasks take arguments as environment variables, prefixed with `PT` (short for Puppet Tasks). Tasks are stored in the `tasks` directory of a module, a module being a directory with a unique name. You can have several tasks per module, but the `init` task is special and will be run by default if a task name is not specified. All of that will make more sense if we see it in action.

Note that tasks can be implemented in any language which will run on the target nodes. We'll use `sh` here purely as a simple demonstration, but you could use Perl, Python, Lua, JavaScript, etc. as long as it can read environment variables or take content on stdin.

Save the following file to `modules/sample/tasks/init.sh`:

```
#!/bin/sh

echo $(hostname) received the message: $PT_message
```

We can then run that task using `bolt`. Note the `message` argument. This will be expanded to the `PT_message` environment variable expected by our task.

```
bolt task run sample message=hello --nodes <nodes> --modules ./modules
```

This should result in output similar to:

```
node1:

node1 got passed the message: hello

Ran on 1 node in 0.39 seconds
```

Try running the `bolt` command with a different value for `message` and you should see the expected results.


# Write your first task in PowerShell

If you're targeting Windows nodes then you might prefer to implement the task in PowerShell. Let's save the following file as `modules/sample/tasks/print.ps1`

```powershell
Write-Output "$env:computername received the message: $env:PT_message"
```

We can then run it via `bolt` on our remote nodes with the following:

```
bolt task run sample::print message="hello powershell" --nodes winrm://<node> --user <user> --password <password> --modules ./modules
```

Note:

* The name of the file on disk (minus any file extension) translates to the name of the task when run via `bolt`, in this case `print`
* The name of the module/directory is also used to find the relevant task, in this case `sample`

# Write your first task in Python

The above examples are obviously very simple. Lets implement something slightly more interesting and useful. We'll use Python for this example but remember Puppet Tasks can be implemented in any language which can be run on the target node.

Note that `bolt` assumes that the required runtime is already available on the target nodes. So for the following examples to work the target nodes should have Python already installed.

Save the following as `modules/sample/gethost.py`: 

```python
#!/usr/bin/env python
import socket
import os

host = os.environ.get('PT_host')

if host:
    print("%s is available at %s on %s" % (host, socket.gethostbyname(host), socket.gethostname()))
else:
    print('No host argument passed')
```

We can then run the task against our nodes like so:

```
$ bolt task run sample::gethost host=google.com --nodes <nodes> --modules ./modules
node1:

google.com is available at 216.58.204.14 on node1

Ran on 1 node in 0.36 seconds
```

The important thing to node above is that our task is just a standard Python script, in this case using parts of the Python standard library. Apart from accepting arguments as `PT`-prefixed environment variables, which will work outside Puppet Tasks too, the script is exactly what you would write to achieve the same task outside Puppet Tasks. `bolt` just gives you the ability to run that script across a large number of nodes quickly and easily. No configuration files or rewriting
required.
