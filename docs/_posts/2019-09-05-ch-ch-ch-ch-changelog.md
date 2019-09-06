---
title: Ch-ch-ch-ch-changelog!
---

It's been two weeks since the last Bolt update and what a two weeks it's been.

In that time, we've completed our move from Jira to GitHub for tracking Bolt issues and work-in-progress. If you want to follow what we're working on, you can now simply [consult our project board](https://github.com/puppetlabs/bolt/projects/2).

We also just released Bolt 1.30 (**thirty**!). You can check out the full list of changes in our shiny new [CHANGELOG.md file](https://github.com/puppetlabs/bolt/blob/master/CHANGELOG.md).

This release has some helpful improvements to output and other fixes, but the highlight is definitely the new pluggable `puppet_library` hook. This satisfies an extremely popular request to be able to customize how Bolt installs Puppet on systems when you call `apply_prep()`.

By default, Bolt will use the `puppet_agent::install` task to install the very latest version of Puppet. That's great if all you care about is getting Puppet on the system so you can use `apply()`. But if you're using Bolt alongside an established Puppet deployment, you probably care a bit more about which version of Puppet gets installed and where it's downloaded from. You may also want to do some additional configuration. With the new `puppet_library` hook, you can do all that and more!

For instance, you can use the `puppetlabs-bootstrap` module to install a Puppet Enterprise agent, connected to a specific puppet master.

```yaml
# bolt.yaml
plugin_hooks:
  puppet_library:
    plugin: task
    task: bootstrap
    parameters:
      master: puppet.example.com
      cacert_content: <cert>
```

This task will download the `puppet-agent` package from the master, install the agent, and configure it to connect to that master. It will even validate the master's certificate using the given CA certificate ensuring mutual trust.

We'll be improving this feature even more in the future, adding the ability to [control the user it runs as](https://github.com/puppetlabs/bolt/issues/1191) and letting the built-in `puppet_agent::install` task [control whether the service starts](https://github.com/puppetlabs/bolt/issues/1204).

We've got a slew of other exciting features that will be landing soon, including a generic task-powered plugin system, a rework of the Target API, and a plugin to generate inventory from Azure VMs.

That's all for now! Tune in next week for an update about our plans for Bolt 2.0.
