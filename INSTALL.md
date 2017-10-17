# Installation

To use Bolt, you'll need to install:

* Ruby 2.0 or greater
* gcc and related dependencies (except on Windows)
* Bolt gem

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
     
Don't forget to accept the xcode license (or you will still get native extension build errors). This can be done from the command line using the following command:
     
     xcodebuild -license accept

### Windows

Install [Chocolatey](https://chocolatey.org/install), then install `ruby`. It isn't necessary
to install `ruby.devkit`, as ffi already publishes precompiled gems for Windows x86 and x64.

    choco install ruby
    refreshenv

If you wish to use `rubocop` on Windows it is necessary to install the `ruby.devkit` and the
MSYS2 base package.

    choco install ruby.devkit
    refreshenv
    ridk install    # Choose the base install and complete the Wizard selections.

## Installing Bolt

Bolt can be installed 3 ways depending on your use case. The most common case is
to install from [RubyGems](https://rubygems.org).

    gem install bolt

Or add this to your Gemfile if you are using [Bundler](https://bundler.io)

    gem 'bolt'

Or if running from source

    git submodule update --init --recursive
    bundle install --path .bundle --without test
    bundle exec bolt ...

If you wish to use `rubocop`, perform the bundle install with no exclusions

    bundle install --path .bundle

See `bolt --help` for more details.

## Installing Puppet

Bolt vendors a version of puppet that supports executing tasks and plans, so you do not need
to install puppet. If you happen to already have puppet installed, then the vendored version
will take precedence and will not conflict with the already installed version.
