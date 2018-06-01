
# Bolt command options

Bolt commands can accept several command line options, some of which are
required to run certain bolt commands.

You must specify target nodes for all bolt commands. Task commands, such as
`bolt run task` and `bolt run plan`, require the `--modules` flag to specify the
location of the task or plan module on the workstation you are running the
command from.


## Specifying nodes

You must specify the target nodes that you want to execute bolt commands on.

For most bolt commands, specify the target nodes with the `--nodes` flag when you
run the command, such as `--nodes mercury`. For plans, the `--nodes` flag will
be mapped to the `nodes` parameter if the plan exposes one.

When targeting machines with the `--nodes` flag, you may specify the transport
either in the node url for each host, such as `--nodes
winrm://mywindowsnode.mydomain`, or set a default transport for the operation
with the `--transport` option. If you do not specify a transport it will
default to `ssh`.

To specify multiple nodes with the `--nodes` flag, use a comma-separated list of
nodes, such as `--nodes neptune,saturn,mars`.

Alternatively, you can use brace expansion on the command line to generate a
node list, specify a node list from a file, or pass a node list on stdin.

To generate a node list with brace expansion, specify the node list with an
equals sign (`=`), such as `--nodes=web{1,2}`.

For example, this command:

```
 bolt command run --nodes={web{5,6,7},elasticsearch{1,2,3}.subdomain}.mydomain.edu
```
runs Bolt on the following hosts:
- elasticsearch1.subdomain.mydomain.edu
- elasticsearch2.subdomain.mydomain.edu
- elasticsearch3.subdomain.mydomain.edu
- web5.mydomain.edu
- web6.mydomain.edu
- web7.mydomain.edu

To pass nodes to Bolt in a file, pass the file name and relative location with
the `--nodes` flag and an `@` symbol: `bolt command run --nodes @nodes.txt`

To pass nodes on `stdin`, on the command line, use a command to generate a node
list, and pipe the result to Bolt with `-` after `--nodes` : `<COMMAND> | bolt command run --nodes -` For
example, if you have a node list in a text file, you might run `cat nodes.txt |
bolt command run --nodes`


### Specifying nodes from an inventory file

To specify nodes from an inventory file, reference nodes by node name, a glob
matching names in the file, or the name of a group of nodes.

For the inventory file example below, the command `--nodes
elastic_search,web_app` matches all nodes in both groups, `elastic_search` and
`web_app`. And `--nodes 'elasticsearch*'` references all the nodes that start with
elasticsearch.


```
groups:
  - name: elastic_search
    nodes:
      - elasticsearch1.subdomain.mydomain.edu
      - elasticsearch2.subdomain.mydomain.edu
      - elasticsearch3.subdomain.mydomain.edu
  - name: web_app
    nodes:
      - web5.mydomain.edu
      - web6.mydomain.edu
      - web7.mydomain.edu
```


### Setting a default transport

To set a default transport protocol, pass it with the command with the `--transport` option.

Pass the `--transport` option after the nodes list, such as `--nodes win1 --transport winrm`

This sets the transport protocol as the default for this command. If you set
this option when running a plan, it is treated as the default transport for the
entire plan run. Any nodes passed with transports in their url or transports
configured in inventory will not use this default.

This is useful on Windows, so that you do not have to include the winrm
transport for each node. To override the default transport, specify the
protocol on a per-host basis, such as `bolt command run facter --nodes
win1,ssh://linux --transport winrm`


## Specifying connection credentials

To run bolt commands on target nodes that require a username and password, pass
credentials as options on the command line.

Bolt connects to remote nodes with either SSH or WinRM. You can manage SSH
connections with an SSH configuration file (`~/.ssh/config`) on your workstation,
or you can specify the username and password on the command line.

WinRM connections always require you to pass the username and password with the
bolt command. For example, this command targets a WinRM node:

```
bolt command run 'gpupdate /force' --nodes winrm://pluto --user Administrator --password <PASSWORD>
```
To have Bolt securely prompt for a password, use the `--password` or `-p` flag
without supplying any value. Bolt will prompt for the password, so that the
password does not appear in a process listing or on the console.


## Specifying the module path

When executing tasks or plans, you must specify the `--modulepath` option as
the directory containing the task modules.

Specify this option in the format `--modulepath </PATH/TO/MODULE>`. This path
should be only the path the modules directory, such as `~/modules`. Do not
specify the module name in this path, as the name is already specified as part
of the task or plan name.

To specify multiple module directories to search for modules, separate the paths with a semicolon
(`;`) on Windows or a colon (`:`) on all other platforms.


## Bolt command reference

The following subcommands, actions, and options are available for the Bolt task runner.

### bolt commands

`Usage: bolt <subcommand> <action> [options]`
Command	Description	Arguments

```
bolt command run <COMMAND>
```
Runs a command on remote nodes.
- The command, single quoted if it contains spaces or special characters.
- The nodes on which to run the command.


```
bolt script run
```
Runs a script in any language that will run on the remote system.
- A path to a local script to run on the remote nodes.
- Optionally, arguments to pass to the script.
- The nodes on which to run the script.

```
bolt task run
```
Runs a task on a remote system, passing any specified parameters.
- The task name, in the format modulename::taskname.
- The module path to the module containing the task.
- The nodes on which to run the task.

```
bolt plan run
```
- Runs a task plan.
- The plan name, in the format modulename::planname.
- The module path to the module containing the plan.
- The nodes on which to run the plan.

```
bolt file upload
```
Uploads a local file to a remote node.
- The path to the source file.
- The path to the remote location.
- The nodes on which to upload the file.

```
bolt task show
```
Displays a list of all the tasks on the modulepath. Will note whether a task supports noop.
- Adding a specific task name displays details and parameters for the task.
- The module path to the module containing the task.
- Optionally, the name of a task you want details for: bolt task show <TASK NAME>

```
bolt plan show
```
- Lists the plans that are installed on the current module path.
- Adding a specific plan name displays details and parameters for the plan.
- The module path to the module containing the plan.

## Command options

Options are optional unless marked as required.

| Options | Description |
| --- | --- |
| `--nodes, -n` | Required when running. Nodes to connect to.<br><br>To connect with WinRM, include the protocol as winrm://<HOSTNAME>.<br><br>For an IPv6 address without a port number, encase it brackets [fe80::34eb:ff1:b584:d7c0].<br><br>For IPv6 addresses including a port use one of the following formats:  fe80::34eb:ff1:b584:d7c0:22  or  [fe80::34eb:ff1:b584:d7c0]:22. |
| `--query` `, -q` |Query PuppetDB to determine the targets.|
| `--noop` |Execute a task that supports it in no-operation mode.|
| `--description` |Add a description to the run. Used in logging and submitted to Orchestrator with the pcp transport.|
| `--params` |Parameters, passed as a JSON object on the command line, or as a JSON parameter file, prefaced with `@` like `@params.json`. For Windows PowerShell, add single quotation marks to define the file: `'@params.json'`

|
||
| Authentication |
| `--user, -u` | User to authenticate as. |
| `--password, -p` | Password to authenticate with. Pass this flag without any value to securely prompt for the password. |
| `--private-key` | Private ssh key to authenticate with |
| `--[no-]host-key-check` | Do not require verification of new hosts in the known_hosts file.<br><br>`host-key-check` and `no-host-key-check` are options for the SSH transport. |
| `--[no-]ssl` | Do not require verification of new hosts in the known_hosts file.<br><br>`ssl` and `no-ssl` are options for WinRM. |
| `--[no-]ssl-verify` | Do not verify remote host SSL certificate with WinRM<br><br>`ssl-verify` and `no-ssl-verify` are options for WinRM. |
||
| Escalation |
| `--run-as` | User to run as using privilege escalation |
| `--sudo-password` | Password for privilege escalation. Omit the value to prompt for the password. |
||
| Run context |
| `--concurrency, -c` | Maximum number of simultaneous connections (default: 100) |
| `--modulepath` | Required for tasks and plans. The path to the module containing the task. Separate multiple paths with a semicolon (`;`) on Windows or a colon (`:`) on all other platforms. |
| `--configfile` | Specify where to load config from (default: ~/.puppetlabs/bolt.yaml) |
| `--inventoryfile` | Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml) |
||
| Transports |
| `--transport` | Specifies the default transport for this command. To override, specify the transport for a given node, such as ssh://linuxnode. |
| `--connect-timeout` | Connection timeout (defaults vary) |
| `--[no-]tty` | Applicable to SSH transport only. Some commands, such as sudo, may require a pseudo TTY to execute. If so, specify --tty |
| `--tmpdir` | The directory to upload and execute temporary files on the target |
||
| Display |
| `--format` | Output format to use: human or json |
| `--[no-]color` | Whether to show output in color |
| `--help, -h` | Displays help for the bolt command. |
| `--verbose` | Display verbose logging |
| `--debug` | Display debug logging |
| `--version` | Displays the Bolt version. |
