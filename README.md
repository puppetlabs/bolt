# Bolt

[![Travis Status](https://api.travis-ci.com/puppetlabs/bolt.svg?token=XsSSSxJhnBoKnL8JPVay&branch=master)](https://travis-ci.com/puppetlabs/bolt)
[![Appveyor Status](https://ci.appveyor.com/api/projects/status/m7dhiwxk455mkw2d/branch/master?svg=true)](https://ci.appveyor.com/project/puppetlabs/bolt/branch/master)
[![Gem Version](https://badge.fury.io/rb/bolt.svg)](https://badge.fury.io/rb/bolt)

Bolt is a Ruby command-line tool for executing commands, scripts, and tasks on remote systems using SSH and WinRM.

* Executes commands on remote *nix and Windows systems.
* Distributes and execute scripts, such as Bash, PowerShell, Python.
* Scales to more than 1000 concurrent connections.
* Supports industry standard protocols (SSH/SCP, WinRM/PSRP) and authentication methods (password, publickey).

> For a step-by-step introduction to Bolt, see our [hands-on-lab](https://github.com/puppetlabs/tasks-hands-on-lab).

## Supported platforms

* Linux, OSX, Windows
* Ruby 2.3+

> For complete usage and installation details, see the [Puppet Bolt docs](https://puppet.com/docs/bolt).
>
> To contribute information, including alternate installation methods and running from source code, see [CONTRIBUTING.md](./CONTRIBUTING.md).

## Installation

### On *nix

Bolt depends on gems containing native extensions. To install Bolt on *nix platforms, you must also install a GNU Compiler Collection (GCC) compiler and related dependencies.

1. Install the dependencies for your platform.

   * On CentOS 7 or Red Hat Enterprise Linux 7, run `yum install -y make gcc ruby-devel`
   * On Fedora 25, run `dnf install -y make gcc redhat-rpm-config ruby-devel rubygem-rdoc`
   * On Debian 9 or Ubuntu 16.04, run `apt-get install -y make gcc ruby-dev`
   * On Mac OS X, run `xcode-select --install`, and then accept the xcode license by running `xcodebuild -license accept`

2. Install Bolt as a gem by running `gem install bolt`

Users of the bash shell can activate command completion by using the completion include file:
```
source <git-checkout>/resources/bolt_bash_completion.sh
```
Add the script to /etc/bash_completion.d/ or add the command to your ".bashrc"

### On Windows

Install Bolt and its dependencies on Windows systems.

To install and use Bolt on Windows systems, you must also install Ruby. You can download Ruby from [https://rubyinstaller.org/](https://rubyinstaller.org/) or with the [Chocolatey](https://chocolatey.org) Windows package manager.

1. Install Ruby.
2. Refresh your environment by running `refreshenv`
3. Install Bolt by running `gem install bolt`

## Configuring Bolt

To configure Bolt, create a `~/.puppetlabs/bolt.yml` file. Global options live at the top level of the file while transport-specific options are configured for each transport. If a config option is set in the config file and passed with the corresponding command line flag, the flag will take precedence.


example config file:
```yaml
---
modulepath: "~/.puppetlabs/bolt-code/site:~/.puppetlabs/bolt-code/modules"
concurrency: 10
format: human
log:
  console:
    level: warn
  ~/.bolt/debug.log:
    level: debug
    append: false
ssh:
  host-key-check: false
  private-key: ~/.ssh/bolt_id
```

### Global configuration options

`concurrency`: The number of threads to use when executing on remote nodes (default: 100)

`format`: The format to use when printing results. Options are `human` and `json` (default: `human`)

`modulepath`: The module path to load tasks and plan code from. This is a list of directories separated by the OS-specific path separator (`:` on Linux/macOS, `;` on Windows).

`log`: The logging configuration. A hash in which each entry describes a single log file - the key is a file path of the log file (optionally prefixed by the `file:` scheme) and the corresponding value is a hash of parameters of that log file. Supported parameters are: `level` - the logging level of the log file and `append` - a boolean flag determining whether the log file should be appended to or rather overwritten on each bolt invocation. A special log file named `console` can be used to override the logging level of the default console log.

`transport`: The transport to use when none is specified in the url(default: `ssh`)

`inventoryfile`: The path to the `inventory.yaml` file(default: `~/.puppetlabs/bolt/inventory.yaml`

### `ssh` transport configuration options

`host-key-check`: If false, host key validation will be skipped when connecting over SSH. (default: true)

`private-key`: The path to the private key file to use for SSH authentication.

`connect-timeout`: Maximum amount of time to allow for an SSH connection to be established, in seconds.

`tmpdir`: The directory to store temporary files on the target node. (default: location used by `mktemp -d`, usually `/tmp`)

`run-as`: Triggers privilege escalation for commands on the target node as the specified user. Currently only works via `sudo`.

### `winrm` transport configuration options

`connect-timeout`: Maximum amount of time to allow for a WinRM connection to be established, in seconds.

`ssl`: If false, skip requiring SSL for connections. (default: true)

`ssl-verify`: If false, skip remote host SSL certificate verification (for self-signed certs). (default: true)

`cacert`: The CA certificate used to authenticate SSL connections. (default: uses system CA certificates)

`tmpdir`: The directory to store temporary files on the target node. (default: `[System.IO.Path]::GetTempPath()`)

`extensions`: List of file extensions that will be accepted for scripts or tasks. Scripts with these file extensions will rely on the target node's file type association to run. For example, if Python is installed on the system, a `.py` script should run with `python.exe`. `.ps1`, `.rb`, and `.pp` are always allowed and run via hard-coded executables.

### `pcp` transport configuration options

`service-url`: The URL of the Orchestrator service, usually of the form `https://puppet:8143`. If not specified, Bolt will attempt to read local PE Client Tools configuration for the same setting from `orchestrator.conf`.

`cacert`: The CA certificate used to authenticate the `service-url`. If not specified, Bolt will attempt to read local PE Client Tools configuration for the same setting from `orchestrator.conf`.

`token-file`: The token certificate used to authorize requests to the `service-url`. If not specified, Bolt will attempt to read local PE Client Tools configuration for the same setting from `orchestrator.conf`. (default: `~/.puppetlabs/token`)

`task-environment`: The environment from which Orchestrator will serve task implementations. (default: `production`)

`local-validation`: Whether or not to perform validation of task parameters against the locally installed copy of a task when the task is run exclusively on targets which use the `pcp` transport. If set to false (and the task is run exclusively on targets which use the `pcp` transport) no validation of the task parameters is performed by bolt and the task doesn't even need to be installed locally. If a task is run on targets which use different transports (which may or may not include `pcp`) the validation of the task parameters is performed irrespective of this setting. (default: false)

### `local` transport configuration options

`tmpdir`: The directory to store temporary files and use as the working directory for local execution. (default: `Dir.mktmpdir`)

### Node-specific configuration with the inventory file

The inventory file allows you to group nodes and set up node-specific configuration defaults.

To set up defaults for ssh and winrm connections, create an inventory file at `~/.puppetlabs/bolt/inventory.yaml` with the following content:

```yaml
groups:
  - name: ssh_nodes
    nodes:
      - sshnode1.example.com
      - sshnode2.example.com
    config:
      transport: ssh
  - name: win_nodes
    nodes:
      - winnode1.example.com
      - winnode2.example.com
    config:
      transport: winrm
      transports:
        winrm:
          ssl: false
```

You can then leave the transport option off of the url when targeting those nodes.

```
$ bolt task run package name=puppet action=status --nodes sshnode1.example.com,winnode1.example.com
```

The global transport option and any transport-specific config option can be set in the inventory file. You can also set `user` and `password` for specific transports.

When an inventory is present, node selection can also be done by specifying group names:

```
$ bolt command run hostname --nodes ssh_nodes
```

or using wildcard matching against node names enumerated in the inventory:

```
$ bolt command run hostname --nodes 'sshnode*.example.com'
```

Note that &mdash; in place of wildcard matching &mdash; shell-specific expansions (such as `sshnode{1,2}.example.com`) can also be useful ways to specify a pattern of nodes to run.

### Querying PuppetDB for targets

In addition to the inventory file, you can query PuppetDB to generate lists of targets.

First, add the necessary configuration to `~/.puppetlabs/bolt.yaml`.

```yaml
puppetdb:
  server_urls: ["https://puppetdb.example.com:8081"]
  cacert: /path/to/cacert
  # Use cert+key for FOSS PuppetDB
  cert: /path/to/cert
  key: /path/to/key
  # Use a token for PE PuppetDB
  token: ~/.puppetlabs/token
```

Now you can target nodes using a PuppetDB query.

```
$ bolt command run hostname --query 'inventory { facts.kernel = "Linux" }'
```

Note that the results of the query must include a `certname` field, which will be used to identify the target.

## Usage examples

### Get help

    $ bolt --help
    Usage: bolt <subcommand> <action> [options]
    ...

### Run a command locally

    $ bolt command run 'ssh -V' --nodes local://localhost
    Started on localhost...
    Finished on localhost:
    STDERR:
        OpenSSH_7.6p1, LibreSSL 2.6.2
    Ran on 1 node in 0.03 seconds

### Run a command over SSH

    $ bolt command run 'ssh -V' --nodes neptune
    Started on neptune...
    Finished on neptune:
    STDERR:
        OpenSSH_6.6.1p1, OpenSSL 1.0.1e-fips 11 Feb 2013
    Ran on 1 node in 0.49 seconds

### Run a command over SSH against multiple hosts

    $ bolt command run 'ssh -V' --nodes neptune,mars
    Started on neptune...
    Started on mars...
    Finished on neptune:
    STDERR:
        OpenSSH_6.6.1p1, OpenSSL 1.0.1e-fips 11 Feb 2013
    Finished on mars:
    STDERR:
        OpenSSH_6.6.1p1, OpenSSL 1.0.1e-fips 11 Feb 2013
    Ran on 2 nodes in 0.44 seconds

### Run a command over WinRM

    $ bolt command run 'gpupdate /force' --nodes winrm://pluto --user Administrator --password <password>
    Started on pluto...
    Finished on pluto:
    STDOUT:
        Updating policy...

        Computer Policy update has completed successfully.

        User Policy update has completed successfully.
    Ran on 1 node in 11.21 seconds

### Run a command over WinRM against multiple hosts

    $ bolt command run '(Get-CimInstance Win32_OperatingSystem).version' --nodes winrm://pluto,winrm://mercury --user Administrator --password <password>
    Started on pluto...
    Started on mercury...
    Finished on pluto:
    STDOUT:
        6.3.9600
    Finished on mercury:
    STDOUT:
        10.0.14393
    Ran on 2 nodes in 6.03 seconds

### Run a bash script

    $ bolt script run ./install-puppet-agent.sh --nodes neptune
    Started on neptune...
    Finished on neptune:
    STDOUT:
        Installed puppet-agent 5.1.0
    Ran on 1 node in 14.01 seconds

### Run a PowerShell script

    $ bolt script run Get-WUServiceManager.ps1 --nodes winrm://pluto --user Administrator --password <password>
    Started on pluto...
    Finished on pluto:
    STDOUT:
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
    Ran on 1 node in 5.47 seconds

### Run the `sql` task from the `mysql` module

    $ bolt task run mysql::sql database=mydatabase sql="SHOW TABLES" --nodes neptune --modulepath ~/modules

### Run the `deploy` plan from the `webserver` module

    $ bolt plan run webserver::deploy version=1.2 --modulepath ~/modules

    Deployed app version 1.2.

Note the `--nodes` option is not used with plans, as they can contain more complex logic about where code is run. A plan can use normal parameters to accept nodes when applicable, as in the next example.

### Run the `single_task` plan from the `sample` module in this repo

    $ bolt plan run sample::single_task nodes=neptune --modulepath spec/fixtures/modules
    neptune got passed the message: hi there

## Kudos

Thank you to [Marcin Bunsch](https://github.com/marcinbunsch) for allowing Puppet to use the `bolt` gem name.

## Contributing

We welcome error reports and pull requests to Bolt. See
[CONTRIBUTING.md](./CONTRIBUTING.md) for how to help.

## License

The gem is available as open source under the terms of the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0).

