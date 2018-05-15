# Writing Tasks

> **Difficulty**: Basic

> **Time**: Approximately 15 minutes

In this exercise you will write your first Puppet Tasks for use with Bolt. 

- [How do tasks work?](#how-do-tasks-work)
- [Write your first task in Bash](#write-your-first-task-in-bash)
- [Write your first task in PowerShell](#write-your-first-task-in-powershell)
- [Write your first task in Python](#write-your-first-task-in-python)

# Prerequisites
Complete the following before you start this lesson:

1. [Installing Bolt](../01-installing-bolt)
1. [Setting up test nodes](../02-acquiring-nodes)
1. [Running Commands](../03-running-commands)
1. [Running Scripts](../04-running-scripts)


# How do tasks work?

Tasks are similar to scripts, you can implement them in any language that runs on your target nodes. But tasks are kept in modules and can have metadata. This allows you to reuse and share them more easily. You can upload and download tasks as modules from the [Puppet Forge](https://forge.puppet.com/), run them from GitHub or use them locally to organize your regularly used commands.

Tasks are stored in the `tasks` directory of a module, a module being a directory with a unique name. You can have several tasks per module, but the `init` task is special and runs by default if you do not specify a task name.

By default tasks take arguments as environment variables prefixed with `PT` (short for Puppet Tasks). 

# Write your first task in Bash

This exercise uses `sh`, but you can use Perl, Python, Lua, or JavaScript or any language that can read environment variables or take content on stdin.

1. Save the following file to `modules/exercise5/tasks/init.sh`:

    ```
    #!/bin/sh
    
    echo $(hostname) received the message: $PT_message
    ```

2. Run the exercise5 task. Note the `message` argument. This will be expanded to the `PT_message` environment variable expected by our task. By naming parameters explicitly it's easier for others to use your tasks.

    ```
    bolt task run exercise5 message=hello --nodes all --modulepath ./modules
    ```
    The result:
    ```
    Started on node1...
    Finished on node1:
      localhost.localdomain received the message: hello
    Ran on 1 node in 0.43 seconds
    ```

3. Run the Bolt command with a different value for `message` and see how the output changes.


# Write your first task in PowerShell

If you're targeting Windows nodes then you might prefer to implement the task in PowerShell. 

1. Save the following file as `modules/exercise5/tasks/print.ps1`

    ```powershell
    Write-Output "$env:computername received the message: $env:PT_message"
    ```

2. Run the exercise5 task. 

    ```
    bolt task run exercise5::print message="hello powershell" --nodes $WINNODE --modulepath ./modules
    ```

    **Note:**
    
    * The name of the file on disk (minus any file extension) translates to the name of the task when run via Bolt, in this case `print`.
    * The name of the module (directory) is also used to find the relevant task, in this case `exercise5`.
    * As with the Bash example above, name parameters so that they're more easily understood by users of the task.

# Write your first task in Python

Note that Bolt assumes that the required runtime is already available on the target nodes. For the following examples to work, Python 2 or 3 must be installed on the target nodes. This task will also work on Windows system with Python 2 or 3 installed.

1. Save the following as `modules/exercise5/tasks/gethost.py`:

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

2. Run the task using the command `bolt task run <task-name> <task options>`.

    ```
    bolt task run exercise5::gethost host=google.com --nodes all --modulepath ./modules
    ```
    The result:
    ```
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

# Next steps

Now that you know how to write tasks you can move on to:

[Downloading and running existing tasks](../06-downloading-and-running-existing-tasks)
