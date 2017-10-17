# Contributing

## Issues

Please submit new issues on the GitHub issue tracker: https://github.com/puppetlabs/bolt/issues

Internally, Puppet uses JIRA for tracking work, so nontrivial bugs or enhancement 
requests may migrate to JIRA tickets in the "BOLT" project: https://tickets.puppetlabs.com/browse/BOLT/ 

## Pull Requests

Pull requests are also welcome on GitHub: https://github.com/puppetlabs/bolt

As with other open-source projects managed by Puppet, you must digitally sign the Contributor 
License Agreement before we can accept your pull request: https://cla.puppet.com

## Installing Bolt

Depending on your development workflow, you can install Bolt one of three ways:

* From [RubyGems](https://rubygems.org)
* From your Gemfile with Bundler
* From source

Bolt vendors a version of Puppet that supports executing tasks and plans, so you do not need to install Puppet. If you happen to already have Puppet installed, then the vendored version takes precedence and does not conflict with the already installed version.

### RubyGems install

To install from [RubyGems](https://rubygems.org), run:

    gem install bolt

### Bundler install

To use [Bundler](https://bundler.io), add this to your Gemfile:

    gem 'bolt'

### Run Bolt from source

To run Bolt from source:

    git submodule update --init --recursive
    bundle install --path .bundle --without test
    bundle exec bolt ...

To use `rubocop`, perform the bundle install with no exclusions

    bundle install --path .bundle

## Testing

Some tests require a Windows or Linux VM. Execute `vagrant up` to bring these up with the Vagrantfile included with the `bolt` gem. Any tests that require this are tagged with `:vagrant` in rspec.

To run all tests, run:

    $ bundle exec rake test

To exclude tests that rely on Vagrant, run:

    $ bundle exec rake unit

### `rubocop` on Windows

To use `rubocop` on Windows, you must install the `ruby.devkit` and the MSYS2 base package.

    choco install ruby.devkit
    refreshenv
    ridk install    # Choose the base install and complete the Wizard selections.


