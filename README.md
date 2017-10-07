# Bolt

[![Travis Status](https://api.travis-ci.com/puppetlabs/bolt.svg?token=XsSSSxJhnBoKnL8JPVay&branch=master)](https://travis-ci.com/puppetlabs/bolt)
[![Appveyor Status](https://ci.appveyor.com/api/projects/status/m7dhiwxk455mkw2d/branch/master?svg=true)](https://ci.appveyor.com/project/puppetlabs/bolt/branch/master)
[![Gem Version](https://badge.fury.io/rb/bolt.svg)](https://badge.fury.io/rb/bolt)

Bolt is a Ruby command-line tool for executing commands, scripts, and tasks on remote systems using SSH and WinRM.

* Executes commands on remote *nix and Windows systems.
* Distributes and execute scripts, such as Bash, PowerShell, Python.
* Scales to more than 1000 concurrent connections.
* Supports industry standard protocols (SSH/SCP, WinRM/PSRP) and authentication methods (password, publickey).

## Supported platforms

* Linux, OSX, Windows
* Ruby 2.0+

## Installation

Install Bolt as a gem by running `gem install bolt`.

See [INSTALL.md](./INSTALL.md) for other ways of installing Bolt and for how to build the native extensions that Bolt depends on.

## Running `bolt` commands

Bolt executes ad hoc commands, runs scripts, transfers files, and runs tasks or task plans on remote nodes from a controller node, such as your laptop or workstation.

When you run `bolt` commands, you must specify the nodes that you want Bolt to execute commands on. You can also specify your username and password for nodes that require credentials.

Bolt connects to remote nodes over SSH by default. To connect over WinRM, you must specify the WinRM protocol when you specify target nodes.

### Specifying nodes

You must specify the target nodes on which to execute `bolt` commands.

For most `bolt` commands, specify the target nodes with the `--nodes` flag when you run the command. Multiple nodes should be comma-separated, such as `--nodes neptune,saturn,mars`. When targeting WinRM machines, you must specify the WinRM protocol in the nodes string. For example, `--nodes winrm://mywindowsnode.mydomain`

The `bolt run plan` command does not accept the `--nodes` flag. For plans, specify nodes as a list within the task plan itself or specify them as regular parameters, like `nodes=neptune`.

### Specifying connection credentials

If you're running `bolt` commands targeting nodes that require a username and password, you must pass those credentials as options on the command line.

Bolt connects to remote nodes with either SSH or WinRM. You can manage SSH connections with an SSH configuration file (`~/.ssh/config`) on the controller node or specify the username and password on the command line. WinRM connections always require you to pass the username and password with the `bolt` command.

For example, this command targets a WinRM node:

```
bolt command run 'gpupdate /force' --nodes winrm://pluto --user Administrator --password <password>
```

## Running arbitrary commands

Bolt can execute arbitrary commands on remote nodes. Specify the command you want to run and what nodes to run the command on.

Specify nodes with node flag, `--nodes` or `-n`. When executing against WinRM nodes, specify the WinRM protocol in the nodes string.

    bolt command run <COMMAND> --nodes <NODE>

    bolt command run <COMMAND> --nodes winrm://mywindowsnode.mydomain --user <USERNAME> --password <PASSWORD>

If the command contains spaces or shell special characters, then you must single quote the command:

    bolt command run '<COMMAND> <ARG1> ... <ARGN>' --nodes <NODE>

## Running scripts

Bolt can copy a script from the local system to the remote system, and then execute it on the remote system.

You can write the script in any language (such as Bash, PowerShell, or Python), providing the appropriate interpreter is installed on the remote system. You must specify the interpreter with a shebang line to execute the script on remote *nix systems.

For example, for a script written in bash, indicate the bash interpreter with a shebang line:

```
#!/bin/bash

echo hello
```

To run the script, specify the path to the script and what nodes to run it on. When running a script on WinRM nodes, specify the WinRM protocol in the nodes string.

```
bolt script run <PATH/TO/SCRIPT> --nodes <NODE>
```

```
bolt script run <PATH/TO/SCRIPT> --nodes winrm://<NODE> --user <USERNAME> --password <PASSWORD>
```

On *nix, Bolt ensures that the script is executable on the remote system before executing it. On remote Windows systems, Bolt currently supports only PowerShell scripts.

## Copying files

Bolt can transfer files from the controller node to specified target nodes.

To transfer a file, run `bolt file upload`, specifying the local path to the file and the destination location on the target node: `bolt file upload <SOURCE> <DESTINATION>`

For example:

```
bolt file upload my_file.txt /tmp/remote_file.txt -n node1,node2
```

## Running tasks

Tasks are similar to scripts, except that tasks must receive input in a specific way. Tasks are also distributed in Puppet modules, so you can write, publish, and download tasks for common operations.

To execute a task, run `bolt task run`, specifying:

* The full name of the task, formatted as `<MODULE::TASK>`, or as `<MODULE>` for `init` tasks.
* Any task parameters, as `parameter=value`.
* The nodes to run the task on and the protocol, if WinRM, with the `--nodes` flag.
* The module path that contains the task module, with the `--modules` flag.
* If required, the username and password to connect to the node, with the `--username` and `--password` flags.


For example, to run the sql task from the mysql module on the `neptune` node:

```
bolt task run mysql::sql database=mydatabase sql="SHOW TABLES" --nodes neptune --modules ~/modules
```

To run an `init` task, call the task by the module name only, and set the task parameters. For example, to run the status action from the package module:

```
bolt run package action=status package=vim --nodes neptune --modules ~/modules
```

## Running plans

Plans allow you to string several tasks together, and can include additional logic to trigger specific tasks.

To execute a plan, run `bolt plan run`, specifying:

* The full name of the plan, formatted as `<MODULE::PLAN>`.
* Any plan parameters, as `parameter=value`.
* The nodes to run the plan on and the protocol, if WinRM, with the `--nodes` flag.
* The module path that contains the plan module, with the `--modules` flag.
* If required, the username and password to connect to the node, with the `--username` and `--password` flags.

For example, if  a plan defined in `mymodule/plans/myplan.pp` accepts a `load_balancer` parameter to specify a node on which to run tasks or functions in the plan, run:

```
bolt plan run mymodule::myplan --modules ./PATH/TO/MODULES load_balancer=lb.myorg.com​
```

### Specifying the module path

When executing tasks or plans, you must specify the `--modules` option as the directory containing the module. Specify this option in the format `--modules /path/to/modules`, should correspond to a directory structure:

```
/path/to/modules/
  mysql/
    tasks/
      sql
```

### Specifying parameters

Tasks can receive input as either environment variables or a JSON hash on standard input. By default, Bolt submits parameters as both environment variables and stdin.

When executing the task, specify the parameter value on the command line in the format `parameter=value`. Pass multiple parameters as a space-separated list.

For example, to run mysql tasks against a database called 'mydatabase', specify the database parameter as `database=mydatabase`.

When you run a command with this parameter, Bolt sets the task's `database` value to mydatabase before it executes the task. It also submits the parameters as JSON to stdin:

```json
{
  "database":"mydatabase"
}
```

Alternatively, you can specify parameters as either a JSON blob or a parameter file with the `--params` flag.

To specify parameters as a JSON blob, use the parameters flag: `--params '{"database": "mydatabase"}'`

To set parameters in a file, create a file called `params.json` and specify parameters there in JSON format.

For example, in your `params.json` file, specify:

```json
{
  "database":"mydatabase"
}
```

Then specify that file on the command line with the parameters flag: `--params @params.json`

### Configuring Puppet Orchestrator for Bolt

Bolt can use the Puppet orchestrator to target nodes using the `pcp` protocol when running on linux.

1. Configure `~/.puppetlabs/client-tools/orchestrator.conf` to include
   service-url and cacert options to connect to you puppet master.
1. Store a PE RBAC token in `~/.puppetlabs/token`.
1. Install the bolt helper task `tasks/init` by installing this repository into
   the production environment on your puppet master. Without this task the
   exec, script and file commands will not work in Bolt.
1. To run tasks over orchestrator the tasks must be installed both on the bolt
   node and into the production environment on the master

## Usage examples

### Get help

    $ bolt --help
    Usage: bolt <subcommand> <action> [options]
    ...

### Run a command over SSH

    $ bolt command run 'ssh -V' --nodes neptune
    neptune:

    OpenSSH_5.3p1, OpenSSL 1.0.1e-fips 11 Feb 2013

    Ran on 1 node in 0.27 seconds

### Run a command over SSH against multiple hosts

    $ bolt command run 'ssh -V' --nodes neptune,mars
    neptune:

    OpenSSH_5.3p1, OpenSSL 1.0.1e-fips 11 Feb 2013

    mars:

    OpenSSH_6.6.1p1, OpenSSL 1.0.1e-fips 11 Feb 2013

    Ran on 2 nodes in 0.27 seconds

### Run a command over WinRM

    $ bolt command run 'gpupdate /force' --nodes winrm://pluto --user Administrator --password <password>
    pluto:

    Updating policy...

    Computer Policy update has completed successfully.

    User Policy update has completed successfully.

    Ran on 1 node in 11.21 seconds

### Run a command over WinRM against multiple hosts

    $ bolt command run '(Get-CimInstance Win32_OperatingSystem).version' --nodes winrm://pluto,winrm://mercury --user Administrator --password <password>
    pluto:

    6.3.9600

    mercury:

    10.0.14393

    Ran on 2 nodes in 6.03 seconds

### Run a bash script

    $ bolt script run ./install-puppet-agent.sh --nodes neptune
    neptune: Installed puppet-agent 5.1.0

### Run a PowerShell script

    $ bolt script run Get-WUServiceManager.ps1 --nodes winrm://pluto --user Administrator --password <password>
    pluto:

    Name                  : Windows Server Update Service
    ContentValidationCert : {}
    ExpirationDate        : 6/18/5254 9:21:00 PM
    IsManaged             : True
    IsRegisteredWithAU    : True
    IssueDate             : 1/1/2003 12:00:00 AM
    OffersWindowsUpdates  : True
    RedirectUrls          : System.__ComObject
    ServiceID             : 3da21691-e39d-4da6-8a4b-b43877bcb1b7
    IsScanPackageService  : False
    CanRegisterWithAU     : True
    ServiceUrl            :
    SetupPrefix           :
    IsDefaultAUService    : True

### Run the `sql` task from the `mysql` module

    $ bolt task run mysql::sql database=mydatabase sql="SHOW TABLES" --nodes neptune --modules ~/modules

### Run the special `init` task from the `service` module

    $ bolt task run service name=apache --nodes neptune --modules ~/modules
    neptune:

    { status: 'running', enabled: true }

### Upload a file

    $ bolt file upload /local/path /remote/path --nodes neptune
    neptune:

    Uploaded file '/local/path' to 'neptune:/remote/path'

### Run the `deploy` plan from the `webserver` module

    $ bolt plan run webserver::deploy version=1.2 --modules ~/modules

    Deployed app version 1.2.

Note the `--nodes` option is not used with plans, as they can contain more complex logic about where code is run. A plan can use normal parameters to accept nodes when applicable, as in the next example.

### Run the `single_task` plan from the `sample` module in this repo

    $ bolt plan run sample::single_task nodes=neptune --modules spec/fixtures/modules
    neptune got passed the message: hi there

## Kudos

Thank you to [Marcin Bunsch](https://github.com/marcinbunsch) for allowing Puppet to use the `bolt` gem name.

## Contributing

Please submit new issues on the GitHub issue tracker: https://github.com/puppetlabs/bolt/issues

Pull requests are also welcome on GitHub: https://github.com/puppetlabs/bolt

As with other open-source projects managed by Puppet, Inc we require contributors to digitally sign the Contributor 
License Agreement before we can accept your pull request: https://cla.puppet.com

Internally, Puppet uses JIRA for tracking work, so nontrivial bugs or enhancement requests may migrate to JIRA tickets 
in the "BOLT" project: https://tickets.puppetlabs.com/browse/BOLT/ 

## Testing

Some tests require a Windows or Linux VM. Execute `vagrant up` to bring these up with the Vagrantfile included with the `bolt` gem. Any tests that require this are tagged with `:vagrant` in rspec.

To run all tests, run:

    $ bundle exec rake test

To exclude tests that rely on Vagrant, run:

    $ bundle exec rake unit

## FAQ

### Bolt requires Ruby >= 2.0

Trying to install Bolt on Ruby 1.9 fails. You must use Ruby 2.0 or greater.

### Bolt fails to install

If you do not have the native extensions Bolt requires, you might get an error like:

```
ERROR:  Error installing bolt:
    ERROR: Failed to build gem native extension.
```

See [Native Extensions](./INSTALL.md#native-extensions) for installation instructions.

### Bolt raises the error `Puppet must be installed to execute tasks`

When using the bolt gem from source, you may receive the error `Puppet must be installed to execute tasks` when trying to run tasks or plans. See [INSTALL.md](./INSTALL.md) on how to install Bolt from source.

### Bolt user and password cannot be specified when running plans

In order to execute a plan, Bolt must be able to SSH (typically using ssh-agent) to each node. For Windows hosts requiring WinRM, plan execution will fail. See [BOLT-85](https://tickets.puppet.com/browse/BOLT-85).

## License

The gem is available as open source under the terms of the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0).

