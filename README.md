# Bolt

[![Travis Status](https://api.travis-ci.com/puppetlabs/bolt.svg?token=XsSSSxJhnBoKnL8JPVay&branch=master)](https://travis-ci.com/puppetlabs/bolt)
[![Appveyor Status](https://ci.appveyor.com/api/projects/status/m7dhiwxk455mkw2d/branch/master?svg=true)](https://ci.appveyor.com/project/puppetlabs/bolt/branch/master)
[![Gem Version](https://badge.fury.io/rb/bolt.svg)](https://badge.fury.io/rb/bolt)

Bolt is a ruby command-line tool for executing commands and scripts on remote
systems using ssh and winrm.

## Goals

* Execute commands on remote *nix and Windows systems
* Distribute and execute scripts, e.g. bash, powershell, python
* Scale to upwards of 1000 concurrent connections
* Support industry standard protocols (ssh/scp, winrm/psrp) and authentication
  methods (password, publickey)

## Supported Platforms

* Linux, OSX, Windows
* Ruby 2.1+

## Getting started

Install it with [RubyGems](https://rubygems.org).

    gem install bolt

Or add this to your Gemfile if you are using [Bundler](https://bundler.io).

    gem 'bolt'

Or run from source

    bundle install --path .bundle

See `bolt --help` for more details.

Bolt relies on gems with native extensions, and the process for building them varies by platform:

### CentOS 7/Redhat 7

    yum install -y make gcc ruby-devel

### Fedora 25

    dnf install -y make gcc redhat-rpm-config ruby-devel rubygem-rdoc

### Debian 9/Ubuntu 16.04

    apt-get install -y make gcc ruby-dev

### OSX

Either install XCode or the Command Line Tools. The latter can be done from the command line:

     xcode-select --install

### Windows

Install [Chocolatey](https://chocolatey.org/install), then install `ruby`. It isn't necessary
to install `ruby.devkit`, as ffi already publishes precompiled gems for Windows x86 and x64.

    choco install ruby
    refreshenv

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

### Run a task from a module

    $ bolt task run package::status name=openssl --nodes neptune --modules ~/modules
    neptune:

    openssl-1.0.1e-16.el6_5.7.x86_64

### Run the `service::init` task from a module

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

Some tests expect a windows or linux vm to be running. Execute `vagrant up` to
bring these up using the included Vagrantfile. Any tests requiring this are
tagged with `:vagrant` in rspec. To run all tests use:

    $ bundle exec rake test

To exclude tests that rely on vagrant run:

    $ bundle exec rake unit

## License

The gem is available as open source under the terms of the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0).

