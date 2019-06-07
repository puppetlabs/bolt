---
title: Running Existing Tasks
difficulty: Intermediate
time: Approximately 10 minutes
---

In this exercise you will explore existing tasks, including several tasks that take advantage of Puppet under-the-hood.

- [Install Puppet using Bolt](#use-the-puppet_agent-module-to-install-puppet-agent)
- [The Tasks Playground](#more-tips-tricks-and-ideas-on-the-tasks-playground)

# Prerequisites
Complete the following before you start this lesson:

1. [Installing Bolt](../01-installing-bolt)
1. [Setting up test nodes](../02-acquiring-nodes)
1. [Running Commands](../03-running-commands)
1. [Running Scripts](../04-running-scripts)

# Inspect installed tasks

Bolt is packaged with useful modules and task content.

Run the 'bolt task show' command to view a list of the tasks installed in the previous exercise.

```shell
bolt task show
```

The result:

```plain
facts                              Gather system facts
facts::bash                        Gather system facts using bash
facts::powershell                  Gather system facts using powershell
facts::ruby                        Gather system facts using ruby and facter
package                            Manage and inspect the state of packages
puppet_agent::install              Install the Puppet agent package
puppet_agent::install_powershell
puppet_agent::install_shell
puppet_agent::version              Get the version of the Puppet agent package installed. Returns nothing if none present.
puppet_agent::version_powershell
puppet_agent::version_shell
puppet_conf                        Inspect puppet agent configuration settings
service                            Manage and inspect the state of services
service::linux                     Manage the state of services (without a puppet agent)
service::windows                   Manage the state of Windows services (without a puppet agent)

Use bolt task show <task-name> to view details and parameters for a specific task.
```

# Use the puppet_agent module to install puppet agent. 

Install puppet agent with the install_agent task

``` shell
bolt task run puppet_agent::install -n all --run-as root
```

The result:

```
Installed:
puppet-agent.x86_64 0:6.0.1-1.el7                                             
 
Complete!
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
 * base: mirror.tocici.com
 * extras: mirror.tocici.com
 * updates: ftp.osuosl.org
No packages marked for update
{
}
Successful on 3 nodes: node1,node2,node3
Ran on 3 nodes in 68.71 seconds
```

# View and use parameters for a specific task

Run `bolt task show package` to view the parameters that the package task uses. 

```shell
bolt task show package
```

The result:

```plain
package - Manage and inspect the state of packages

USAGE:
bolt task run --nodes <node-name> package action=<value> name=<value> version=<value> provider=<value>

PARAMETERS:
- action: Enum[install, status, uninstall, upgrade]
    The operation (install, status, uninstall and upgrade) to perform on the package
- name: String[1]
    The name of the package to be manipulated
- version: Optional[String[1]]
    Version numbers must match the full version to install, including release if the provider uses a release moniker. Ranges or semver patterns are not accepted except for the gem package provider. For example, to install the bash package from the rpm bash-4.1.2-29.el6.x86_64.rpm, use the string '4.1.2-29.el6'.
- provider: Optional[String[1]]
    The provider to use to manage or inspect the package, defaults to the system package manager

MODULE:
built-in module
```

Using parameters for the package task, check on the status of the bash package:

```shell
bolt task run package action=status name=bash --nodes node1
```

The result:

```    
Started on node1...
Finished on node1:
  {
    "status": "up to date",
    "version": "4.2.46-30.el7"
  }
Successful on 1 node: node1
Ran on 1 node in 3.84 seconds
```

Using parameters for the package task, install the vim package across all your nodes:

```shell
bolt task run package action=install name=vim --nodes all --run-as root
```

The result:

```
Started on node1...
Started on node3...
Started on node2...
Finished on node1:
  {
    "status": "present",
    "version": "2:7.4.160-4.el7"
  }
Finished on node3:
  {
    "status": "installed",
    "version": "2:7.4.160-4.el7"
  }
Finished on node2:
  {
    "status": "installed",
    "version": "2:7.4.160-4.el7"
  }
Successful on 3 nodes: node1,node2,node3
Ran on 3 nodes in 10.03 seconds
```

# More tips, tricks and ideas on the Tasks Playground

See the [installing modules](https://puppet.com/docs/bolt/latest/bolt_installing_modules.html) documentation to learn how to install external modules. 
These exercises introduce you to Bolt tasks. You'll find lots more tips, tricks, examples and hacks on the [Bolt Tasks Playground](https://github.com/puppetlabs/tasks-playground).

# Next steps

Now that you know how to run existing tasks with Bolt you can move on to:

[Writing Plans](../07-writing-plans)
