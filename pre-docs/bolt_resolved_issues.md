# Resolved issues

Security and bug fixes in the Bolt 1.x release series.

## Error when puppet\_agent task not run as root \(1.1.0\)

The puppet\_agent task now checks that it is run as root. When run as another user, it prints and fails with a helpful message. \([BOLT-878](https://tickets.puppetlabs.com/browse/BOLT-914)\)

## Bolt suppresses errors from transport \(1.1.0\)

Previously, Bolt suppressed some exception errors thrown by transports. For example, when the ed25519 gem was not present for an Net::SSH process, the NotImplementedError for ed25519 keys would not appear. These errors are now identified and displayed. \([BOLT-922](https://tickets.puppetlabs.com/browse/BOLT-922)\)

## Loading bolt/executor is "breaking" gettext setup in spec tests \(1.0.0\)

When Bolt is used as a library, it no longer loads code from r10k unless you explicitly `require 'bolt/cli'`.\([BOLT-914](https://tickets.puppetlabs.com/browse/BOLT-914)\)

## Deprecated functions in stdlib result in Evaluation Error \(1.0.0\)

Manifest blocks will now allow use of deprecated functions from stdlib, and language features governed by the 'strict' setting in Puppet. \([BOLT-900](https://tickets.puppetlabs.com/browse/BOLT-900)\)

## Bolt apply does not provide clientcert fact \(1.0.0\)

`apply_prep` has been updated to collect agent facts as listed in [Puppet agent facts](https://puppet.com/docs/puppet/6.0/lang_facts_and_builtin_vars.html#puppet-agent-facts). \([BOLT-898](https://tickets.puppetlabs.com/browse/BOLT-898)\)

## C:\\Program Files\\Puppet Labs\\Bolt\\bin\\bolt.bat is non-functional \(1.0.0\)

When moving to Ruby 2.5, the .bat scripts in Bolt packaging reverted to hard-coded paths that were not accurate. As a result Bolt would be unusable outside of PowerShell. The .bat scripts have been fixed so they work from cmd.exe as well. \([BOLT-886](https://tickets.puppetlabs.com/browse/BOLT-886)\)

