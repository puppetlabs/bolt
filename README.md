# Bolt

[![Travis Status](https://api.travis-ci.com/puppetlabs/bolt.svg?token=XsSSSxJhnBoKnL8JPVay&branch=master)](https://travis-ci.com/puppetlabs/bolt)
[![Appveyor Status](https://ci.appveyor.com/api/projects/status/m7dhiwxk455mkw2d/branch/master?svg=true)](https://ci.appveyor.com/project/puppetlabs/bolt/branch/master)
[![Gem Version](https://badge.fury.io/rb/bolt.svg)](https://badge.fury.io/rb/bolt)

Bolt is a Ruby command-line tool for executing commands and scripts on remote systems using SSH and WinRM.

## Goals

* Execute commands on remote *nix and Windows systems.
* Distribute and execute scripts, such as Bash, PowerShell, Python.
* Scale to 1000 or more concurrent connections.
* Support industry standard protocols (SSH/SCP, WinRM/PSRP) and authentication
  methods (password, publickey)

## Supported Platforms

* Linux, OSX, Windows
* Ruby 2.1+

## Overview

Bolt provides the ability to execute commands, scripts, and tasks on remote systems using SSH and WinRM.

### Commands

Bolt can execute arbitrary commands:

    $ bolt command run <command>

If the command contains spaces or shell special characters, then you must single
quote the command:

    $ bolt command run '<command> <arg1> ... <argN>'

### Scripts

Bolt can copy a script from the local system to the remote system, and then execute it on the remote system. The script can be written in any language (such as Bash, PowerShell, Python), providing the appropriate interpreter is installed on the remote system. Bolt relies on shebang lines [TODO: relies on them for what? More details here would be great, probably just a bit more] when executing the script on remote *nix systems.

On *nix, Bolt ensures that the script is executable on the remote system before executing it. On remote Windows systems, Bolt currently supports only PowerShell scripts.

### Tasks

Tasks are similar to scripts, except that tasks expect to receive input in a specific way. Tasks are also distributed in Puppet modules, so you can write, publish, and download tasks for common operations. Bolt uses Puppet to discover and load locally installed modules, so Puppet must be installed on the local controller node for tasks to work.

Tasks receive input either as environment variables or as a JSON hash on standard input. For example, when executing the task:

[TODO this is three possible ways to do this, not a description of the first thing]

    $ bolt task run package::status name=openssl

Bolt sets the `PT_name` environment variable to `openssl` prior to executing
the `status` task in the `package` module.

Bolt also submits the parameters as JSON to stdin, for example:

```json
{
  "name":"openssl"
}
```

By default, Bolt submits parameters via environment variables and stdin. You can specify how the task should receive metadata by setting `input_method` in the task's metadata.

When executing the `package::status` task from above, you must specify the `--modules` option as the directory containing the `package` module. [TODO: why? the example does not specify this?] For example, the option `--modules /path/to/modules` should correspond to a directory structure:

    /path/to/modules/
      package/
        tasks/
          status

## Installation

The most common way of installing Bolt is to install from [RubyGems](https://rubygems.org).

    $ gem install bolt

Make sure to read [INSTALL.md](./INSTALL.md) for other ways of installing Bolt, and how to build the native extensions that Bolt depends on.

## Examples

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

### Run the `status` task from the `package` module

    $ bolt task run package::status name=openssl --nodes neptune --modules ~/modules
    neptune:

    openssl-1.0.1e-16.el6_5.7.x86_64

### Run the special `init` task from the `service` module

    $ bolt task run service name=apache --nodes neptune --modules ~/modules
    neptune:

    { status: 'running', enabled: true }

### Upload a file

    $ bolt file upload /local/path /remote/path --nodes neptune
    neptune:

    Uploaded file '/local/path' to 'neptune:/remote/path'

## Kudos

Thank you to [Marcin Bunsch](https://github.com/marcinbunsch) for allowing
Puppet to use the `bolt` gem name.

## Contributing

Issues are tracked at https://tickets.puppetlabs.com/browse/TASKS/

Pull requests are welcome on GitHub at https://github.com/puppetlabs/bolt.

## Testing

Some tests expect a windows or Linux VM to be running. Execute `vagrant up` to bring these up with the Vagrantfile included with the `bolt` gem. Any tests that require this are tagged with `:vagrant` in rspec. To run all tests, run:

    $ bundle exec rake test

To exclude tests that rely on Vagrant, run:

    $ bundle exec rake unit

## FAQ

### Bolt requires ruby >= 2.1

Trying to install Bolt on Ruby 1.9 or 2.0 will fail. You must use Ruby 2.1 or greater.

### Bolt fails to install

```
ERROR:  Error installing bolt:
    ERROR: Failed to build gem native extension.
```

See [Native Extensions](./INSTALL.md#native-extensions).

### Bolt fails to execute a task

The `puppet` gem must be installed on the controller node in order to run tasks.
If it is not installed, then you will receive an error:

    Puppet must be installed to execute tasks

See [installing Puppet](./INSTALL.md#installing-puppet) for more information.

### Bolt does not support submitting task arguments via stdin to PowerShell

Tasks written in PowerShell receive arguments only as environment variables.

## Reference

TODO: add list of commands, any arguments they accept, and any options they accept.

## License

The gem is available as open source under the terms of the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0).

