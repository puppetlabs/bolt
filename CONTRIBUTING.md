# Contributing

## Issues

Please submit new issues on the GitHub issue tracker: https://github.com/puppetlabs/bolt/issues

Internally, Puppet uses JIRA for tracking work, so nontrivial bugs or enhancement
requests may migrate to JIRA tickets in the "BOLT" project: https://tickets.puppetlabs.com/browse/BOLT/

## Types of Improvements

The Bolt ecosystem is extensible via Puppet modules such as those hosted on the [Forge](https://forge.puppet.com/). Many improvements to the Bolt plan ecosystem can be added there as new modules.

There are certain types of improvements that we believe make sense in Bolt itself:

* New Transports. Transports API is a work-in-progress, but is something we aim to stabilize. Currently these can't be extended via modules, although in the future they likely will be.
* Core functionality we believe makes Bolt a better tool, such as the `aggregate` and `canary` plans included in `modules`.
* New functions
    * New core functions that use Bolt internals such as the Executor, Applicator, or Inventory should live in bolt-modules/boltlib.
    * Other directories under bolt-modules are used to categorize Bolt's standard library functions.
* New ways of interacting with plan progress and output, such as prompts to continue or output processors.
* New inventory sources. This is experimental right now, but we're working towards patterns for getting inventory into Bolt and how to refer to it from within a plan.

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

    bundle install --path .bundle --with test
    bundle exec rake rubocop

### Contributing to bundled modules

Some module content is included with the Bolt gem for out-of-the-box use. Some of those modules are included in this repository and others are managed with the Puppetfile included in this repository. All the bundled modules are installed in the `modules` directory.

To change external modules (to add a new module or bump the version), update the Puppetfile and then run `bundle exec r10k puppetfile install`.

## Testing

Some tests require a Windows VMs or Linux containers. For Linux tests (recommended, if you're not sure) run `docker-compose up -d --build` from `spec/` directory. For windows tests, execute `vagrant up` from the root of the bolt repo to bring these up with the provided Vagrantfile. Any tests that require this are tagged with `:winrm` or `:ssh` in rspec.

Additional tests may run in a local environment and require certain shell capabilities. Currently the only case is a Bash-like environment and is tagged with `:bash` in rspec.

To run all tests, run:

    $ bundle exec rake test

To run specific versions of tagged tests, run the `integration` target with the tag appended, e.g.:

    $ bundle exec rake integration:bash

To exclude tests that rely on Vagrant, run:

    $ bundle exec rake unit

Windows includes additional tests that require a full Windows Server VM to run; we run them in AppVeyor. If you need to run the tests locally set `APPVEYOR_AGENTS=true`, re-run `vagrant up` to create a `Windows Server 2016 Core` VM, and run tests with

    $ BOLT_WINRM_PORT=35985 BOLT_WINRM_SMB_PORT=3445 BOLT_WINRM_USER=vagrant BOLT_WINRM_PASSWORD=vagrant bundle exec rake integration:appveyor_agents

### `rubocop` on Windows

To use `rubocop` on Windows, you must install the `ruby.devkit` and the MSYS2 base package.

    choco install ruby.devkit
    refreshenv
    ridk install    # Choose the base install and complete the Wizard selections.
