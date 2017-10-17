# Contributing

## Quick Start

    $ git clone git@github.com:puppetlabs/bolt.git
    $ cd bolt
    $ git submodule init
    $ git submodule update
    $ bundle install --path .bundle/gems/
    $ bundle exec rake unit

Expected output are passing unit tests.  If you receive some failures, it's
likely your sub-modules aren't initialized and up to date.

## Issues

Please submit new issues on the GitHub issue tracker: https://github.com/puppetlabs/bolt/issues

Internally, Puppet uses JIRA for tracking work, so nontrivial bugs or enhancement requests may migrate to JIRA tickets 
in the "BOLT" project: https://tickets.puppetlabs.com/browse/BOLT/ 

## Pull Requests

Pull requests are also welcome on GitHub: https://github.com/puppetlabs/bolt

As with other open-source projects managed by Puppet, Inc we require contributors to digitally sign the Contributor 
License Agreement before we can accept your pull request: https://cla.puppet.com

## Testing

Some tests require a Windows or Linux VM. Execute `vagrant up` to bring these up with the Vagrantfile included with the `bolt` gem. Any tests that require this are tagged with `:vagrant` in rspec.

To run all tests, run:

    $ bundle exec rake test

To exclude tests that rely on Vagrant, run:

    $ bundle exec rake unit
