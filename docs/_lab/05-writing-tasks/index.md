---
title: Writing Tasks
difficulty: Basic
time: Approximately 15 minutes
---

In this exercise you will write your first Bolt Tasks for use with Bolt. 

- [How Do Tasks Work?](#how-do-tasks-work)
- [Write Your First Task in Bash](#write-your-first-task-in-bash)
- [Write Your First Task in PowerShell](#write-your-first-task-in-powershell)
- [Write Your First Task in Python](#write-your-first-task-in-python)

## Prerequisites
Complete the following before you start this lesson:

- [Installing Bolt](../01-installing-bolt)
- [Setting Up Test Nodes](../02-acquiring-nodes)
- [Running Commands](../03-running-commands)
- [Running Scripts](../04-running-scripts)


## How Do Tasks Work?

Tasks are scripts with optional metadata, and can be implemented in any language that runs on your target nodes. Tasks are stored and shared in Puppet modules. By giving your script metadata and including it in a Puppet module, tasks make scripts easy to reuse and share. You can upload and download tasks in modules from the [Puppet Forge](https://forge.puppet.com/), run them from GitHub, or use them locally to organize your regularly used commands.

Tasks are stored in the `tasks` directory of a module, a module being a directory with a unique name. You can have several tasks per module, but the `init` task is special and runs by default if you do not specify a task name.

By default tasks take arguments as environment variables prefixed with `PT`. 

## Write Your First Task in Bash

This exercise uses `sh`, but you can use Perl, Python, Lua, or JavaScript or any language that can read environment variables or take content on stdin.

Save the following to `Boltdir/site-modules/exercise5/tasks/init.sh`:

```shell
{% include lesson1-10/Boltdir/site-modules/exercise5/tasks/init.sh -%}
```

By default, Bolt will search both the `modules` and `site-modules` directories in a Bolt project directory for a matching task name. Typically, any project-specific tasks will be saved to the `site-modules` directory.

Run the exercise5 task. Note the `message` argument. This will be expanded to the `PT_message` environment variable expected by our task. By naming parameters explicitly it's easier for others to use your tasks.

```shell
bolt task run exercise5 message=hello --nodes node1
```

The result:

```
Started on node1...
Finished on node1:
  localhost.localdomain received the message: hello
  {
  }
Successful on 1 node: node1
Ran on 1 node in 0.99 seconds
```

Run the Bolt command with a different value for `message` and see how the output changes.


## Write Your First Task in PowerShell

If you're targeting Windows nodes then you might prefer to implement the task in PowerShell. 

Save the following as `Boltdir/site-modules/exercise5/tasks/print.ps1`:

```powershell
{% include lesson1-10/Boltdir/site-modules/exercise5/tasks/print.ps1 -%}
```

Run the exercise5 task. Note that since the task is not named `init`, you must prepend the name of the task with the name of its module like so `module::task`.

```shell
bolt task run exercise5::print message="hello powershell" --nodes windows
```

The result:

```
Started on localhost...
Finished on localhost:
  Nano received the message: hello powershell
  {
  }
Successful on 1 node: winrm://localhost:55985
Ran on 1 node in 3.87 seconds
```

**Note:**

* The name of the file on disk (minus any file extension) translates to the name of the task when run via Bolt, in this case `print`.
* The name of the module (directory) is also used to find the relevant task, in this case `exercise5`.
* As with the Bash example above, name parameters so that they're more easily understood by users of the task.
* By default tasks with a `.ps1` extension executed over WinRM use PowerShell standard agrument handling rather than being supplied as prefixed environment variables or via `stdin`. 

## Write Your First Task in Python

When running a task, Bolt assumes that the required runtime is already available on the target nodes. For the following examples to work, Python 2 or 3 must be installed on the target nodes. This task will also work on Windows system with Python 2 or 3 installed.

Save the following as `Boltdir/site-modules/exercise5/tasks/gethost.py`:

```python
{% include lesson1-10/Boltdir/site-modules/exercise5/tasks/gethost.py -%}
```

Run the task using the command `bolt task run <task-name>`.

```shell
bolt task run exercise5::gethost host=google.com --nodes linux
```

The result:

```
Started on node1...
Finished on node1:
  google.com is available at 172.217.3.206 on localhost.localdomain
  {
    "host": "google.com",
    "hostname": "localhost.localdomain",
    "ipaddr": "172.217.3.206"
  }
Successful on 1 node: node1
Ran on 1 node in 0.97 seconds
```

## Next Steps

Now that you know how to write tasks you can move on to:

[Downloading and Running Existing Tasks](../06-downloading-and-running-existing-tasks)
