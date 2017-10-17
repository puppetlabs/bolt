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

> For complete usage and installation details, see the [Puppet Bolt docs](https://puppet.com/docs/bolt). For contribution information, including alternate installation methods and running from source, see [CONTRIBUTING.md](./CONTRIBUTING.md).

## Installation

### On *nix

Bolt depends on gems containing native extensions. To install Bolt on *nix platforms, you must also install a GNU Compiler Collection (GCC) compiler and related dependencies.

1. Install the dependencies for your platform.

   * On CentOS 7 or Red Hat Enterprise Linux 7, run `yum install -y make gcc ruby-devel`
   * On Fedora 25, run `dnf install -y make gcc redhat-rpm-config ruby-devel rubygem-rdoc`
   * On Debian 9 or Ubuntu 16.04, run `apt-get install -y make gcc ruby-dev`
   * On Mac OS X, run `xcode-select --install`, and then accept the xcode license by running `xcodebuild -license accept`

2. Install Bolt as a gem by running `gem install bolt`

### On Windows

Install Bolt and its dependencies on Windows systems.

To install and use Bolt on Windows systems, you must also install Ruby. You can download Ruby from [https://rubyinstaller.org/](https://rubyinstaller.org/) or with the [Chocolatey](https://chocolatey.org) Windows package manager.

1. Install Ruby.
2. Refresh your environment by running `refreshenv`
3. Install Bolt by running gem install bolt


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

We welcome error reports and pull requests to Bolt. See
[CONTRIBUTING.md](./CONTRIBUTING.md) for how to help.

## License

The gem is available as open source under the terms of the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0).

