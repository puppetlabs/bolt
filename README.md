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
    bundle exec bolt exec --nodes <name> command='hostname -f'

See `bolt --help` for more details.

## Kudos

Thank you to [Marcin Bunsch](https://github.com/marcinbunsch) for allowing
Puppet to use the `bolt` gem name.

## Contributing

Issues are tracked at https://tickets.puppetlabs.com/browse/TASKS/

Pull requests are welcome on GitHub at https://github.com/puppetlabs/bolt.

## Testing

Some tests expect a windows or linux vm to be running. Execute `vagrant up` to
bring these up using the included Vagrantfile. Any tests requiring this are
tagged with `:vagrant` in rspec. To exclude these tests run:

    $ bundle exec rspec spec --tag ~vagrant

## License

The gem is available as open source under the terms of the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0).

