# Installation

Bolt can be installed 3 ways depending on your use case. The most common case is
to install from [RubyGems](https://rubygems.org).

    gem install bolt

Since bolt is not public yet, you will need to install the gem from our internal
mirror, and specify a version to ensure you get the latest version:

    gem install --source http://rubygems.delivery.puppetlabs.net bolt -v '> 0.0.1'

Or add this to your Gemfile if you are using [Bundler](https://bundler.io).

    gem 'bolt'

Or if running from source

    bundle install --path .bundle
    bundle exec bolt ...

See `bolt --help` for more details.

## Native Extensions

Bolt is written entirely in Ruby, but it depends on gems containing native
extensions. In order to install bolt on a supported platform, you will need a
gcc compiler and related dependencies (except for Windows).

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

## Installing Puppet

Bolt relies on an unreleased version of Puppet 5.2 to execute tasks. As a
temporary workaround you can clone bolt and run it using bundler

    git clone git@github.com:puppetlabs/bolt
    cd bolt
    bundle install --path .bundle
    bundle exec bolt task run <name> --modules ~/modules ...

