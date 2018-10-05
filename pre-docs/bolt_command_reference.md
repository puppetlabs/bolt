---
author: Jean Bond <jean@puppet.com\>
---

# Bolt command reference

Review the subcommands, actions, and options that are available for Bolt.

## Common Bolt commands

Bolt commands use the syntax: `bolt <subcommand> <action> [options]` 

|Command|Description|Arguments|
|-------|-----------|---------|
| `bolt command run` `<COMMAND>` |Runs a command on remote nodes.| -   The command, single quoted if it contains spaces or special characters.

-   The nodes on which to run the command.


 |
| `bolt script run` |Runs a script in any language that will run on the remote system.| -   A path to a local script to run on the remote nodes.

-   Optionally, arguments to pass to the script.

-   The nodes on which to run the script.


 |
| `bolt task run` |Runs a task on a remote system, passing any specified parameters.| -   The task name, in the format `modulename::taskname`.

-   The module path to the module containing the task.

-   The nodes on which to run the task.


 |
| `bolt plan run` |Runs a task plan.| -   The plan name, in the format `modulename::planname`.

-   The module path to the module containing the plan.

-   The nodes on which to run the plan.


 |
| `bolt file upload` |Uploads a local file to a remote node.| -   The path to the source file.

-   The path to the remote location.

-   The nodes on which to upload the file.


 |
| `bolt task show` | Lists all the tasks on the modulepath. Will note whether a task supports no-operation mode.

 | -   Adding a specific task name displays details and parameters for the task.

-   The module path to the module containing the task.

-   Optionally, the name of a task you want details for: `bolt task show <TASK NAME>` 


 |
| `bolt plan show` | Lists the plans that are installed on the current module path.

 | -   Adding a specific plan name displays details and parameters for the plan.

-   The module path to the module containing the plan.


 |

## Command options

Options are optional unless marked as required. 

|Option|Description|
|------|-----------|
|`--nodes`, `-n` | **Required****when running**. Nodes to connect to.

 To connect with WinRM, include the protocol as `winrm://<HOSTNAME>`.

 For an IPv6 address without a port number, encase it brackets `[fe80::34eb:ff1:b584:d7c0]`.

 For IPv6 addresses including a port use one of the following formats:  `fe80::34eb:ff1:b584:d7c0:22 ` or  `[fe80::34eb:ff1:b584:d7c0]:22`.

 |
| `--query` `, -q` |Query PuppetDB to determine the targets.|
| `--noop` |Execute a task that supports it in no-operation mode.|
| `--description` |Add a description to the run. Used in logging and submitted to Orchestrator with the PCP transport.|
| `--params` | Parameters, passed as a JSON object on the command line, or as a JSON parameter file, prefaced with `@` like `@params.json`. For Windows PowerShell,  add single quotation marks to define the file: `'@params.json'` 

 |

## Authentication options

|Option|Description|
|------|-----------|
|`--user`, `-u`|User to authenticate as.|
|`--password`, `-p`|Password to authenticate with. Pass this flag without any value to securely prompt for the password.|
| `--private-key` |Private ssh key to authenticate with|
| `--host-key-check, --no-host-key-check` | Do not require verification of new hosts in the `known_hosts` file.

 `host-key-check` and `no-host-key-check` are options for the SSH transport.

 |
|`--ssl`, `--no-ssl`| Do not require verification of new hosts in the `known_hosts` file.

 `ssl` and `no-ssl` are options for WinRM.

 |
| `--ssl-verify`, `--no-ssl-verify` | Do not verify remote host SSL certificate with WinRM

 `ssl-verify` and `no-ssl-verify` are options for WinRM.

 |

## Escalation options

|Option|Description|
|------|-----------|
| `--run-as` |User to run as using privilege escalation.|
| `--sudo-password` |Password for privilege escalation. Omit the value to prompt for the password.|

## Run context options

|Option|Description|
|------|-----------|
|`--concurrency`, `-c`|Maximum number of simultaneous connections \(default: 100\).|
| `--modulepath` |**Required for tasks and plans**. The path to the module containing the task. Separate multiple paths with a semicolon \(`;`\) on Windows or a colon \(`:`\) on all other platforms.|
| `--configfile` |Specify where to load config from \(default: `bolt.yaml` inside the `Boltdir`\).|
| `--boltdir` |Specify what Boltdir to load config from \(default: autodiscovered from current working dir\).|
| `--inventoryfile` |Specify where to load inventory from \(default: `inventory.yaml` inside the `Boltdir`\).|

## Transport options

|Option|Description|
|------|-----------|
| `--transport` |Specifies the default transport for this command. To override, specify the transport for a given node, such as `ssh://linuxnode`.|
| `--connect-timeout` |Connection timeout \(defaults vary\).|
|`--tty`, `--no-tty`|Applicable to SSH transport only. Some commands, such as `sudo`, may require a pseudo TTY to execute. If so, specify `--tty`.|
| `--tmpdir` | Determines the directory to upload and execute temporary files on the target.

 |

## Display options

|Option|Description|
|------|-----------|
| `--format` |Determines the output format to use: human readable or JSON.|
|`--color`, `--no-color`|Whether to show output in color.|
|`--help`, `-h`|Shows help for the `bolt` command.|
| `--verbose` |Shows verbose logging.|
| `--debug` |Shows debug logging.|
| `--version` |Shows the Bolt version.|

