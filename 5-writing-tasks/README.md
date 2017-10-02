# Writing Tasks

> **Difficulty**: Basic

> **Time**: Approximately 15 minutes

In this lab you will ...

- [Write your first task in Bash](#write-your-first-task-in-bash)
- [Write your first task in Python](#write-your-first-task-in-python)
- [Write your first task in PowerShell](#write-your-first-task-in-powershell)

# Prerequisites

For the following exercises you should already have `bolt` installed and have a few nodes (either Windows or Linux) available to run commands against. The following guides will help:

1. [Installing Bolt](../1-installing-bolt)
1. [Acquiring nodes](../2-acquiring-nodes)

It is also useful to have some familiarity with running commands with `bolt` so you understand passing nodes and credentials. The following lab is recommended:

1. [Running Commands](../3-running-commands)

# Write your first task in Bash 

Tasks allow you to share commonly used commands as Puppet modules. This means they can be uploaded and downloaded from the Forge, as well as managed using all the existing Puppet tools. You can also just use them from GitHub or as a way of organizing regularly used commands locally. 

By default tasks take arguments as environment variables, prefixed with `PT` (short for Puppet Tasks). Tasks are stored in the `tasks` directory of a module, a module just being a directory with a unique name. You can have several tasks per module, but the `init` task is special and will be run by default if a task name is not specified. All of that will make more sense if we see it in action.

Note that tasks can be implemented in any language which will run on the target nodes. We'll use `sh` here purely as a simple demonstration, but you could use Perl, Python, Lua, JavaScript, etc. as long as it can read environment variables or take content on stdin.

Save the following file to `./modules/sample/tasks/init.sh`:

```
#!/bin/sh

echo $(hostname) got passed the message: $PT_message
```

We can then run that task using `bolt` like so. Note the `message` argument. This will be expanded to the `PT_message` environment variable expected by our task.

```
bolt task run sample message=hello <nodes> --modules ./modules
```

This should result in output similar to:

```
bolt_ssh_1:

bolt_ssh1 got passed the message: hello

Ran on 1 node in 0.39 seconds
```

Try running the `bolt` command with a different value for `message` and you should see the expected results.

# Write your first task in Python

# Write your first task in PowerShell
