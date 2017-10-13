# Contributing

## Issues

Please submit new issues on the GitHub issue tracker: https://github.com/puppetlabs/bolt/issues

Internally, Puppet uses JIRA for tracking work, so nontrivial bugs or enhancement requests may migrate to JIRA tickets
in the "BOLT" project: https://tickets.puppetlabs.com/browse/BOLT/

## Pull Requests

Pull requests are also welcome on GitHub: https://github.com/puppetlabs/bolt

As with other open-source projects managed by Puppet, Inc we require contributors to digitally sign the Contributor
License Agreement before we can accept your pull request: https://cla.puppet.com

## Pulling down the code

In order to test locally you will either need to have in your system gems or from source include the submodules. This will allow you to execute without having the VM for the `bundle exec rake unit` task.

```
git submodule update --init --recursive
bundle install --path .bundle
```

## Testing

Some tests require a Windows or Linux VM. Execute `vagrant up` to bring these up with the Vagrantfile included with the `bolt` gem. Any tests that require this are tagged with `:vagrant` in rspec.

To run all tests, run:

    $ bundle exec rake test

To exclude tests that rely on Vagrant, run:

    $ bundle exec rake unit
