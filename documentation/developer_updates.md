# Developer updates

Find out what the Bolt team is working on and why we're making the decisions
we're making.

## November 2020

### Puppet 7 Release Prep

[Puppet 7](https://puppet.com/docs/puppet/7.0/puppet_index.html) is set to be released November
19th, 2020. While the Bolt package won't be pulling in Puppet 7 until early next year, the
`puppet_agent::install` task bundled with Bolt will pick up Puppet 7 agents by default when the
packages are available. This means that using the `apply_prep()` Bolt plan function or the install
task directly will be pulling in a major version bump for the agent. While we don't anticipate any
of the changes in the agent to affect Bolt users, if you find you need to use the Puppet 6 agent, you
can configure `apply_prep()` and the `puppet_agent::install` task to do so.

The `puppet_agent::install` task accepts a `collections` parameter that tells the task which
collection to download the package from. This defaults to `puppet` which maps to the latest
collection, but you can set this value to `puppet6` to pull in the latest Puppet 6 agent. You can
pass this parameter on the command line:

_\*nix shell command_
```
bolt task run puppet_agent::install -t mytargets collection='puppet6'
```

_PowerShell cmdlet_
```
Invoke-BoltTask -Name puppet_agent::install -Targets mytargets collection='puppet6'
```

Or to the `run_task()` plan function:
```
run_task('puppet_agent::install', $targets, { collection => 'puppet6' })
```

If you need the `apply_prep()` plan function to install the Puppet 6 agents instead of Puppet 7, you
can configure this by [configuring the puppet_library plugin
hook](using_plugins.md#puppet-library-plugins) in either `bolt-project.yaml` or
`bolt-defaults.yaml`:

```
plugin_hooks:
  puppet_library:
    task: puppet_agent
    collection: puppet6
```

## September 2020

### Module management in Bolt projects

We've recently finished work on a major improvement to Bolt projects: module
management! With this improvement, you no longer need to manually manage your
modules and their dependencies in a Puppetfile and can instead automate that
process with Bolt.

So why did we make this change to how Bolt manages modules? Because managing a
project's modules could be a frustrating process that includes multiple steps:

- Find the module you want to add to your project
- Find all of the dependencies for that module
- Determine which version of each module is compatible with every other module
  you have installed
- Manually update your Puppetfile to include each module
- Install the Puppetfile

By offloading most of this work to Bolt, you now only need to list the modules
you care about in your project configuration. Bolt takes care of resolving a
module's dependencies and installing compatible versions. This greatly
simplifies the process of managing your project's modules:

- Find the module you want to add to your project
- Tell Bolt to install the module with all of its dependencies

With these changes, we've also updated where Bolt installs modules. You no
longer need to worry about accidentally overwriting local modules when you
install a Puppetfile, because Bolt installs modules to a special directory that
is not part of the configured modulepath.

The new module management feature is available starting with **Bolt 2.30.0**. To
try it out, opt in by updating your project. You can learn more about this
feature and opting in at [Managing modules in Bolt
projects](managing_modules.md).
