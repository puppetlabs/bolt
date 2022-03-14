# Using Bolt with Hiera

Because Bolt uses Puppet as a library, it has access to Hiera. Hiera is a
built-in key-value configuration data lookup system, which lets you separate
data from your code. There are some key differences in how Bolt and Puppet use
Hiera, which this page covers in more detail.

Before you start using Hiera in Bolt, get familiar with:
- [How to use Hiera](https://puppet.com/docs/puppet/latest/hiera_intro.html).
- [Applying Puppet code](applying_manifest_blocks.md) with Bolt.

## Hiera configuration layers

In Bolt, Hiera uses two independent layers of configuration when you look up
data: the project layer and the module layer. This is different from Puppet,
where Hiera has three independent layers of configuration. Bolt searches the two
layers of configuration in the order: project → module.

### Project layer

The configuration file for the project layer is located, by default, at
`<PROJECT>/hiera.yaml`.

The project layer is equivalent to the environment layer in Puppet. This is
where you define most of your Hiera data hierarchy. Every project has a
hierarchy configuration, which applies to all lookups made from that project.

You can specify a different configuration file for the project layer by setting
the `hiera-config` option in your project configuration, or by using the
`--hiera-config` command-line option.

### Module layer

The configuration for a module layer is located, by default, in the module's
root directory at `<MODULE>/hiera.yaml`.

The module layer sets default values and merge behavior for a module’s class
parameters. The module layer comes last in Hiera’s lookup order, so environment
data set by a user overrides the default data set by the module’s author.

📖  **Related information**

- [bolt-project.yaml options](bolt_project_reference.md#hiera-config)
- [*nix shell commands](bolt_command_reference.md)
- [PowerShell cmdlets](bolt_cmdlet_reference.md)
## Look up data in plans

You can use the [Puppet `lookup()`
function](https://puppet.com/docs/puppet/latest/hiera_automatic.html#puppet_lookup)
in plans to look up data. It's useful to think of looking up Hiera data in Bolt
plans in two different contexts: inside apply blocks and outside apply blocks.

### Inside apply blocks

Inside apply blocks, Bolt compiles Puppet catalogs in a per-target context, and
has unfettered access to Hiera data. You can use the same Hiera configuration
and data you would for Puppet, and look up data in the same way as you would in
Puppet.

Before executing an apply block in a plan, you typically run the `apply_prep()`
function on all of the targets that you run the apply on. As part of the
`apply_prep()` function, Bolt collects facts for each target and sets them on
the target. When Bolt compiles Puppet catalogs for each of these targets, the
context includes the target's facts, which you can use in interpolations in your
Hiera configuration.

Given the following Hiera configuration at `<PROJECT DIRECTORY>/hiera.yaml`:

```yaml
# hiera.yaml
version: 5

hierarchy:
  - name: "Per-OS defaults"
    path: "os/%{facts.os.family}.yaml"
  - name: "Common data"
    path: "common.yaml"
```

And the following data source at `<PROJECT DIRECTORY>/data/os/windows.yaml`:

```yaml
# data/os/windows.yaml
confpath: "C:\Program Files\Common Files\my_tool.conf"
```

And the following plan at `<PROJECT DIRECTORY>/plans/configure.pp`:

```puppet
# plans/configure.pp
plan my_project::configure (
  TargetSpec $targets
) {
  $targets.apply_prep

  $apply_result = apply($targets) {
    file { lookup('confpath'):
      ensure  => file,
      content => 'setting: false'
    }
  }

  return $apply_result
}
```

Because the apply block includes a `lookup()`, Hiera performs the following
steps during the plan run:

1. Hiera checks the `facts.os.family` fact for the target, since the first level
   of the hierarchy includes an interpolation for this fact.
1. Hiera looks for the `confpath` key in the appropriate data source. If the
   target's OS is Windows, it checks `<PROJECT DIRECTORY>/data/os/windows.yaml`.
1. Hiera finds the `confpath` key in the data source and returns the value
   `C:\Program Files\Common Files\my_tool.conf` from the `lookup()` function.

After looking up the `confpath` key, Bolt uses this code to compile the Puppet
catalog for the target:

```puppet
file { 'C:\Program Files\Common Files\my_tool.conf':
  ensure  => file,
  content => 'setting: false'
}
```

### Outside apply blocks

Outside apply blocks, Bolt is essentially executing a script. It doesn't have a
concept of a target or context, and thus cannot load per-target data. This
breaks common Hiera features like interpolating target facts.

Given the following Hiera configuration at `<PROJECT DIRECTORY>/hiera.yaml`:

```yaml
# hiera.yaml
version: 5

hierarchy:
  - name: "Per-target data"
    path: "targets/%{trusted.certname}.yaml"
  - name: "Common data"
    path: "common.yaml"
```

And the following plan at `<PROJECT DIRECTORY>/plans/request.pp`:

```puppet
# plans/request.pp
plan my_project::request (
  TargetSpec $targets
) {
  $api_key = lookup('api_key')
  $result  = run_task('make_request', $targets, 'api_key' => $api_key)

  return $result
}
```

Running the plan results in an error like this:

```shell
$ bolt plan run my_project::request --targets server
Starting: plan my_project::request
Finished: plan my_project::example in 0.01 sec
{
  "kind": "bolt/pal-error",
  "msg": "Interpolations are not supported in lookups outside of an apply block: Undefined variable 'trusted' (file: /Users/bolt/.puppetlabs/bolt/hiera.yaml)",
  "details": {
  }
}
```

The plan run fails because the lookup takes place outside of an apply block,
which does not include per-target data such as facts, and the hierarchy includes
an interpolation for the `trusted.certname` fact.

To look up data outside of apply blocks, you can add a `plan_hierarchy` key to
your Hiera configuration. The `plan_hierarchy` key is specified at the same
level as the `hierarchy` key and is used whenever you look up data outside of an
apply block.

Given the following Hiera configuration file at `<PROJECT
DIRECTORY>/hiera.yaml`:

```yaml
# hiera.yaml
version: 5

hierarchy:
  - name: "Per-target data"
    path: "targets/%{trusted.certname}.yaml"
  - name: "Common data"
    path: "common.yaml"

plan_hierarchy:
  - name: "Static data"
    path: "static.yaml"
```

And the following data source at `<PROJECT DIRECTORY>/data/static.yaml`:

```yaml
# data/static.yaml
api_key: 12345
```

The plan run now succeeds, because Hiera uses the `plan_hierarchy` key to look
up the static value for `api_key`.

By specifying both keys in the same Hiera configuration, you can look up data
inside and outside apply blocks in the same plan. This allows you to use your
existing Hiera configuration in Bolt plans without encountering an error if
per-target interpolations exist and your plan tries to look up data outside an
apply block.

### Interpolations outside apply blocks

Interpolations are not well supported in the `plan_hierarchy` hierarchy.
Target-level data such as facts are not available to lookups outside of apply blocks,
so the normal hierarchy interpolation does not work. The `lookup()` function
only interpolates based on the variables currently in scope.

The following example demonstrates interpolating the `$application` variable
into a `plan_hierarchy` hierarchy:

Given the following configuration at `<PROJECT DIRECTORY>/hiera.yaml`:

```yaml
# hiera.yaml
version: 5

plan_hierarchy:
  - name: "Application data"
    path: "%{application}.yaml"
```

A data source at `<PROJECT DIRECTORY>/data/kittycats.yaml`:

```yaml
# data/kittycats.yaml
site_path: /var/www/kittycats.tld/public_html
```

And a data source at `<PROJECT DIRECTORY>/data/doggos.yaml`:

```yaml
# data/doggos.yaml
site_path: /var/www/doggos.tld/public_html
```

Bolt looks up the site path and passes the value to a task to deploy the site:

```puppet
# plans/plan_lookup.pp
plan plan_lookup(
  TargetSpec $targets,
  String     $application = 'doggos'
) {
  $site_path = lookup('site_path')
  run_task("deploy_site", $targets, 'path' => $site_path)
}
```

Note that if you tried to call `lookup('site_path')` from a sub-plan of
`plan_lookup`:

```puppet
# plans/plan_lookup.pp
plan plan_lookup(
  TargetSpec $targets,
  String $application = 'doggos'
) {
  $site_path = lookup('site_path')
  run_task("deploy_site", $targets, 'path' => $site_path)
}
```

```puppet
# plans/other_plan.pp
plan other_plan(
  TargetSpec $targets
) {
  lookup('site_path')
  ...
}
```

Bolt would error, because `$application` is not in scope in `other_plan` and the
interpolation in the Hiera configuration would fail.

## Look up data from the command line

You can use the `bolt lookup` command and `Invoke-BoltLookup` PowerShell cmdlet
to look up Hiera data from the command line. By default, Bolt uses the `hierarchy`
key in your `hiera.yaml` file to look up data and performs the lookup inside an apply
block. Similar to looking up data outside of an apply block in a plan, you can use
the `--plan-hierarchy` or `-PlanHierarchy` command options to look up data from 
the `plan_hierarchy` key. 

### Inside apply blocks

Without additional options, the `lookup` command looks up data in the context of a target,
allowing you to interpolate target facts and variables in your hierarchy.

When you run the `bolt lookup` and `Invoke-BoltLookup` commands, Bolt first
runs an `apply_prep` on each of the targets specified. This installs the
`puppet-agent` package on the target, collects facts, and then stores the facts
on the target to be used in interpolations.

Looking up data from the command line is particularly useful if you need to
debug a plan that includes calls to the `lookup()` function, or if you need to
look up target-specific data such as a password for authenticating connections
to the target.

Given the following Hiera configuration at `<PROJECT DIRECTORY>/hiera.yaml`:

```yaml
# hiera.yaml
version: 5

hierarchy:
  - name: "Per-OS defaults"
    path: "os/%{facts.os.name}.yaml"
  - name: "Common data"
    path: "common.yaml"
```

A data source at `<PROJECT DIRECTORY>/data/os/Windows.yaml`:

```yaml
# data/os/Windows.yaml
password: Bolt!
```

And a data source at `<PROJECT DIRECTORY>/data/os/Ubuntu.yaml`:

```yaml
# data/os/Ubuntu.yaml
password: Puppet!
```

You can look up the value for the `password` key from the command line using
facts collected from your targets:

_\*nix shell command_

```shell
bolt lookup password --targets windows_target,ubuntu_target
```

_PowerShell cmdlet_

```powershell
Invoke-BoltLooup -Key 'password' -Targets 'windows_target,ubuntu_target'
```

Bolt prints the value for the key to the console:

```shell
Starting: install puppet and gather facts on windows_target, ubuntu_target
Finished: install puppet and gather facts with 0 failures in 6.7 sec
Finished on windows_target:
  Bolt!
Finished on ubuntu_target:
  Puppet!
Successful on 2 targets: windows_target, ubuntu_target
Ran on 2 targets
```

### Outside apply blocks

To look up data from Hiera's `plan_hierarchy` key, use the `lookup` command with
the `--plan-hierarchy` option. This mimics performing a lookup outside an apply block
in a Bolt plan.

Because `plan_hierarchy` values are not specific to individual targets, this command performs
just one lookup and returns the bare value. You can't use the `--plan-hierarchy` option
with the `--targets`, `--rerun`, or `--query` options.

If your `plan_hierarchy` contains [interpolations from plan
variables](#interpolations-outside-apply-blocks), you can pass values to interpolate to `lookup`:

_\*nix shell command_
```
bolt lookup key --plan-hierarchy plan_var=interpolate_me
```

_PowerShell cmdlet_
```
Invoke-BoltLookup -Key key -PlanHierarchy plan_var=interpolate_me
```
