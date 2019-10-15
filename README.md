# Bolt

[![Travis Status](https://travis-ci.org/puppetlabs/bolt.svg?branch=master)](https://travis-ci.org/puppetlabs/bolt)
[![Appveyor Status](https://ci.appveyor.com/api/projects/status/m7dhiwxk455mkw2d/branch/master?svg=true)](https://ci.appveyor.com/project/puppetlabs/bolt/branch/master)
[![Gem Version](https://badge.fury.io/rb/bolt.svg)](https://badge.fury.io/rb/bolt)

<div name="logo">
  <img src="resources/bolt-logo-dark.png"
  style="display: block; margin-left: auto; margin-right: auto;"
  width="50%"
  alt="bolt logo">
</div>

Bolt is a Ruby command-line tool for executing commands, scripts, and tasks on remote systems using SSH and WinRM.

* Executes commands on remote *nix and Windows systems.
* Distributes and execute scripts, such as Bash, PowerShell, Python.
* Scales to more than 1000 concurrent connections.
* Supports industry standard protocols (SSH/SCP, WinRM/PSRP) and authentication methods (password, publickey).

> For a step-by-step introduction to Bolt, see our [hands-on-lab](https://puppetlabs.github.io/bolt/).

Additionally the Bolt project includes:

* [bolt-server](developer-docs/bolt-api-servers.md), an experimental HTTP API for executing tasks over SSH and WinRM.
* bolt-inventory-pdb, a command-line tool for generating an inventory file from a template containing PuppetDB queries.

> Installing bolt from a gem is not recommended since core modules will not be available. Please [install bolt](https://puppet.com/docs/bolt/latest/bolt_installing.md) as a package

## Supported platforms

* Linux, OSX, Windows
* Ruby 2.3+

> For complete usage and installation details, see the [Puppet Bolt docs](https://puppet.com/docs/bolt).
>
> For contributing information, including alternate installation methods and running from source code, see [CONTRIBUTING.md](./CONTRIBUTING.md).

* [Install](https://puppet.com/docs/bolt/latest/bolt_installing.html)
* [Bolt Commands](https://puppet.com/docs/bolt/latest/bolt_command_reference.html)
* [Configure](https://puppet.com/docs/bolt/latest/configuring_bolt.html)
    * [Node-specific Configuration with the Inventory File](https://puppet.com/docs/bolt/latest/inventory_file.html)
    * [Connect to PuppetDB](https://puppet.com/docs/bolt/latest/bolt_connect_puppetdb.html)
* [Puppet Tasks and Plans](https://puppet.com/docs/bolt/latest/writing_tasks_and_plans.html)
    * [Inspecting Tasks and Plans](https://puppet.com/docs/bolt/latest/inspecting_tasks_and_plans.html)
    * [Running Tasks](https://puppet.com/docs/bolt/latest/bolt_running_tasks.html)
    * [Running Plans](https://puppet.com/docs/bolt/latest/bolt_running_plans.html)
    * [Installing Tasks and Plans](https://puppet.com/docs/bolt/latest/installing_tasks_from_the_forge.html)
    * [Writing Tasks](https://puppet.com/docs/bolt/latest/writing_tasks.html)
    * [Writing Plans](https://puppet.com/docs/bolt/latest/writing_plans.html)
* [Applying Manifest Blocks in Plans](https://puppet.com/docs/bolt/latest/applying_manifest_blocks.html)

## Getting Help

* [#bolt on Slack](https://slack.puppet.com/) - Join the Bolt developers and community

## Kudos

Thank you to [Marcin Bunsch](https://github.com/marcinbunsch) for allowing Puppet to use the `bolt` gem name.

## Contributing

We welcome error reports and pull requests to Bolt. See
[CONTRIBUTING.md](./CONTRIBUTING.md) for how to help.

## License

The gem is available as open source under the terms of the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0).

