[![Modules Status](https://github.com/puppetlabs/bolt/workflows/Modules/badge.svg?branch=main)](https://github.com/puppetlabs/bolt/actions)
[![Linux Status](https://github.com/puppetlabs/bolt/workflows/Linux/badge.svg?branch=main)](https://github.com/puppetlabs/bolt/actions)
[![Windows Status](https://github.com/puppetlabs/bolt/workflows/Windows/badge.svg?branch=main)](https://github.com/puppetlabs/bolt/actions)
[![Version](https://img.shields.io/github/v/tag/puppetlabs/bolt?label=version)](./CHANGELOG.md)
[![Platforms](https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-lightgrey)](./documentation/bolt_installing.md)
[![License](https://img.shields.io/github/license/puppetlabs/bolt)](./LICENSE)

<p align="center">
  <img src="resources/bolt-logo-dark.png" width="50%" alt="bolt logo"/>
</p>

Bolt is an open source orchestration tool that automates the manual work it takes to maintain your infrastructure. Use Bolt to automate tasks that you perform on an as-needed basis or as part of a greater orchestration workflow. For example, you can use Bolt to patch and update systems, troubleshoot servers, deploy applications, or stop and restart services. Bolt can be installed on your local workstation and connects directly to remote targets with SSH or WinRM, so you are not required to install any agent software.

### Bring order to the chaos with orchestration

Run simple plans to rid yourself of the headaches of orchestrating complex workflows. Create and share Bolt plans to easily expand across your application stack.

### Use what you have to automate simple tasks or complex workflows

Get going with your existing scripts and plans, including YAML, PowerShell, Bash, Python or Ruby, or reuse content from the [Puppet Forge](https://forge.puppet.com).

### Get up and running with Bolt even faster

Speed up your Bolt knowledge with a step-by-step introduction to basic Bolt functionality with our [getting started guide](https://puppet.com/docs/bolt/latest/getting_started_with_bolt.html) and [self-paced training](https://puppet.com/learning-training/kits/intro-to-bolt).

More information and documentation is available on the [Bolt website](https://puppet.com/docs/bolt/latest/bolt.html).

## Supported platforms

Bolt can be installed on Linux, Windows, and macOS. For complete installation details, see the [installation docs](./documentation/bolt_installing.md).

For alternate installation methods and running from source code, see our [contributing guidelines](https://github.com/puppetlabs/bolt/blob/main/CONTRIBUTING.md).

## Getting help

Join [#bolt](https://slack.puppet.com/) on the Puppet Community slack to chat with Bolt developers and the community.

## Contributing

We welcome error reports and pull requests to Bolt. See our [contributing guidelines](./CONTRIBUTING.md) for how to help.

## Kudos

Thank you to [Marcin Bunsch](https://github.com/marcinbunsch) for allowing Puppet to use the `bolt` gem name.

## License

Bolt is available as open source under the terms of the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) license.


## Design Decisions

<!-- adrlog -->

* [ADR-0001](developer-docs/adr/0001-fail-bolt-execution-if-no-bolt-forge-token-present.md) - Fail bolt execution if no BOLT_FORGE_TOKEN present
* [ADR-0002](developer-docs/adr/0002-verify-that-bolt-module-dependencies-are-valid.md) - Verify that bolt module dependencies are valid

<!-- adrlogstop -->
