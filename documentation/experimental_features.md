# 🧪 Experimental features

Most larger Bolt features are released initially in an experimental or unstable
state. This allows the Bolt team to gather feedback from real users quickly
while iterating on new functionality. Almost all experimental features are
eventually stabilized in future releases. While a feature is experimental, its
API may change, requiring the user to update their code or configuration. The
Bolt team attempts to make these changes painless by providing useful warnings
around breaking behavior where possible. 

## Streaming output

This feature was introduced in [Bolt 3.2.0](https://github.com/puppetlabs/bolt/blob/main/CHANGELOG.md#bolt-310-2021-3-08).

You can set the new `stream` output option in `bolt-project.yaml` or `bolt-defaults.yaml`, or
specify the option on the command line as `--stream`. Bolt streams results back to the console as
they are received, with the target's safe name (the URI without the password included) and the
stream (either 'out' or 'err') appended to the message, like so:
```
Started on docker://puppet_6_node...
Started on docker://puppet_7_node...
[docker://puppet_7_node] out: Hello!
[docker://puppet_6_node] out: Hello!
Finished on docker://puppet_7_node:
  Hello!
Finished on docker://puppet_6_node:
  Hello!
```

As you can see, when you configure output to stream, Bolt might print to the console twice:
once as the actions are running, and again after Bolt prints the results.

## LXD Transport

This feature was introduced in [Bolt 3.2.0](https://github.com/puppetlabs/bolt/blob/main/CHANGELOG.md#bolt-310-2021-3-08).

The LXD transport supports connecting to Linux containers on the local system. Similar to the Docker
transport, The LXD transport accepts the name of the container as the URI, and connects to the
container by shelling out to the `lxc` command. The example inventory file below demonstrates
connecting to a Linux container target named `ubuntuone`.

```
targets:
  - uri: lxd://ubuntuone
    config:
      lxd:
        tmpdir: /root/tmp
```

## Plugin caching

This feature was introduced in [Bolt
2.37.0](https://github.com/puppetlabs/bolt/blob/main/CHANGELOG.md#bolt-2370-2020-12-07).

Bolt supports the use of plugins to dynamically load information during a Bolt run and change how
Bolt executes certain actions. Bolt also loads all configuration plugins for most Bolt commands, and
all inventory plugins for any action that requires the inventory, even if the action only uses a
subset of targets from the inventory. Plugins can sometimes take a long time to execute, and several
plugin invocations can add quite a bit of start up time to any Bolt command regardless of whether it
uses the plugin results.

To mitigate the time it takes for Bolt to load plugins, we've introduced plugin caching. Plugin
caching is enabled by configuring a Time to Live (TTL) for the cache, either by setting a default
TTL for all plugins with the `plugin-cache` project configuration option or by setting `ttl` under
the `_cache` option for an individual plugin invocation. The TTL is always in seconds. Bolt caches
plugin results inside the Bolt project, and removes all expired cache entries whenever it
uses a cache result. This prevents cache entries from getting orphaned and never removed. Bolt
identifies a cache result based on a hash (delightfully named 'bubblebabble') of the entire plugin
invocation, minus the `_cache` key. If any element of the plugin invocation changes, Bolt reloads
the plugin and updates the cache.

You can set `ttl` to 0 to disable caching for a particular plugin. Caching is disabled by default,
so this is mostly useful if you have a default cache `ttl` configured under `plugin-cache` in your
`bolt-project.yaml` or `bolt-defaults.yaml` and want to disable caching for individual plugin
invocations.

> **NOTE**: Plugin results are currently cached in plaintext. Encrypted caching is planned for a
future release.

Users can clear all cache entries using the `--clear-cache` or `-ClearCache` command-line option
with any Bolt command.

This inventory sets a TTL of 1 hour, or 3600 seconds, for the PuppetDB plugin:
```
targets:
  - _plugin: puppetdb
    _cache:
      ttl: 3600
    query: "inventory[certname] { facts.osfamily = 'RedHat' }"
    target_mapping:
      name: certname
```

This config file sets a default TTL of 30 minutes, or 1800 seconds, for all plugins:
```
plugin-cache:
  ttl: 1800
```

> **NOTE**: The same cache and cache configuration is used for the `resolve_reference()` plan
function.

## `Parallelize()` function

This feature was introduced in [Bolt
2.35.0](https://github.com/puppetlabs/bolt/tree/main/CHANGELOG.md#bolt-2350-2020-11-16).

Bolt plan functions have always run concurrently across targets - that is, if a function takes a
list of targets and operates on them, the function runs that step on each target in parallel. For
example, the following plan runs `hostname` on all targets at the same time, waits for all targets
to finish, and then runs `whoami` on all targets at the same time. 

```
# $targets = target1,target2,target3
plan myplan(TargetSpec $targets) {
  run_command('hostname', $targets)
  run_command('whoami', $targets)
}
```

In the example above, `target3` has to wait for `hostname` to finish on `target1` and `target2`
before it can run `whoami`. The experimental `parallelize()` function accepts an array and a block,
and runs the entire block on each array element in parallel. Inside a parallelize block, targets can
run subsequent plan functions before all targets have finished each step. For example, here is the
same plan with a parallelize block:

```
# $targets = target1,target2,target3
plan myplan(TargetSpec $targets) {
  # Convert the input into an array of targets
  $ts = get_targets($targets)

  parallelize($ts) |$target| {
    run_command('hostname', $target)
    run_command('whoami', $target)
  }
}
```

Here, if `target3` completes running `hostname` before `target1` or `target2`, it can continue directly to
running `whoami`.

This functionality is particularly useful for plan functions that may take a long time on certain
targets but not on others, or for plans where some long running process may fail on a target but the
plan author wants the plan to be able to continue quickly on successful targets.

Within the parallelize block, only the following functions can run in parallel: 
- `run_command`
- `run_task`
- `run_task_with`
- `run_script`
- `upload_file`
- `download_file`. 
You can run other functions from a parallelize block, but those functions will block execution
on other targets until they complete. For example, in the following plan, Bolt can start running
`task2` and `task3` while `task1` is still executing. However, it cannot start `task4` while
`out::message` is executing on any of the targets.

```
# $targets = target1,target2,target3
plan myplan(TargetSpec $targets) {
  # Convert the input into an array of targets
  $ts = get_targets($targets)

  parallelize($ts) |$target| {
    run_task('task1', $target)
    run_task('task2', $target)
    $result = run_task('task3', $target)
    out::message($result)
    run_task('task4', $target)
  }
}
```

The `parallelize()` function returns an array that contains the results of executing the block in
the same order as the input array. You can think of `parallelize()` as a `map` function that runs in
parallel. The 'result' of the block for a particular input is either a value passed to a `return`
statement, the result of the last function in the block, or an error. For example, consider the
following plan:

```
# $ts = [target1, target2, target3]
$result = parallelize($ts) |$target| {
    if target.name == 'target1' {
      return "Don't run the task on this target"
    }
    run_task('task1', $target)
    run_command('hostname', $target)
  }

# This will print ["Don't run the task on this target", "target2", "target3"]
out::message($result)
```

If any step of the block errors, Bolt stops executing the block for that target, but continues
executing for all other targets from the input array. When the block finishes, if there is an error
in the result array, the plan throws a `PlanFailure` and includes the entire result array in the
`details` key of the failure. If the block is wrapped in a `catch_errors()` block, Bolt catches the
`PlanFailure` and continues executing the plan.

## `ResourceInstance` data type

This feature was introduced in [Bolt
2.10.0](https://github.com/puppetlabs/bolt/blob/main/CHANGELOG.md#bolt-2100-2020-05-18).

Bolt has had a limited ability to interact with Puppet's Resource Abstraction
Layer. You could use the `apply` function to generate catalogs and return
events, and the `get_resources` plan function can be used to query resources on
a target. The `ResourceInstance` data type is the first step in enabling plan
authors to build resource-based logic into their plans to enable a
discover-inspect-execute workflow for interacting with resources on remote
systems.

Use the `ResourceInstance` data type is used to store information about a single
resource on a target, including its observed state, desired state, and any
related events.

> **Note::** The `ResourceInstance` data type does not interact with or modify
  resources in any way. It is only used to store information about a resource.

### Creating `ResourceInstance` objects

#### `Target.set_resources()`

The recommended way to create `ResourceInstance` objects is by setting them
directly on a `Target` object using the `Target.set_resources` function. Use the
function to set one or more resources on a target at a time. You can read more
about this function in [Bolt plan functions](plan_functions.md#set_resources).

The `Target.set_resources` function can set existing `ResourceInstance` objects
on a target, or take hashes of parameters to create new `ResourceInstance`
objects and automatically set them on a target.

When setting resources using a hash of parameters, you can pass either a single
hash or an array of hashes:

```ruby
$init_hash = {
  'target'        => Optional[Target],
  'type'          => Variant[String[1], Type[Resource]],
  'title'         => String[1],
  'state'         => Optional[Hash[String[1], Data]],
  'desired_state' => Optional[Hash[String[1], Data]],
  'events'        => Optional[Array[Hash[String[1], Data]]]
}

$target.set_resources(
  Variant[Hash[String[1], Any], Array[Hash[String[1], Any]]] init_hash
)
```

> **Note:** When passing a data hash to `Target.set_resources`, the `target`
  parameter is **optional**. If the `target` parameter is not specified, the
  function automatically sets the target to the target the function is called
  on.

> **Note:** If the `target` parameter is any target other than the one you are
  setting the resource on, Bolt will raise an error.

When setting resources using existing `ResourceInstance` objects, you can pass
either a single `ResourceInstance` or an array of `ResourceInstance` objects.

```ruby
$resource = ResourceInstance.new(...)

$target.set_resources(
  Variant[ResourceInstance, Array[ResourceInstance]] resource
)
```

> **Note:** If the target for a `ResourceInstance` does not match the target it
  is being set on, Bolt will raise an error.

A target can only have a single instance of a given resource. If you set a
duplicate resource on a target, Bolt shallow merges the `state` and
`desired_state` of the duplicate resource with the `state` and `desired_state`
of the existing resource and adds any `events` for the duplicate resource to the
existing resource.

#### `ResourceInstance.new()`

You can also create standalone `ResourceInstance` objects without setting them
directly on a target using the `new` function.

The `new` function accepts either positional arguments:

```ruby
ResourceInstance.new(
  Target                                 target,
  Variant[String[1], Type[Resource]]     type,
  String[1]                              title,
  Optional[Hash[String[1], Data]]        state,
  Optional[Hash[String[1], Data]]        desired_state,
  Optional[Array[Hash[String[1], Data]]] events
)
```

or a hash of arguments:

```ruby
$init_hash = {
  'target'        => Target,
  'type'          => Variant[String[1], Type[Resource]],
  'title'         => String[1],
  'state'         => Optional[Hash[String[1], Data]],
  'desired_state' => Optional[Hash[String[1], Data]],
  'events'        => Optional[Array[Hash[String[1], Data]]]
}

ResourceInstance.new(
  Hash[String[1], Any] init_hash
)
```

### Accessing `ResourceInstance` object on a Target

You can retrieve a specific `ResourceInstance` object stored on a Target in a
plan using the `resource()` function:

```
$packages = $target.get_resources(Package).first['resources']
$target.set_resources($packages)
$resource = $target.resource(Package, 'openssl')
out::message($resource.reference)
```

### Attributes

Each `ResourceInstance` has the following attributes:

| Parameter | Type | Description |
| --- | --- | --- |
| `target` | The target that the resource is for. | `Target` |
| `type` | The [type of the resource](https://puppet.com/docs/puppet/latest/type.html). This can be either the stringified name of the resource type or the actual type itself. For example, both `"file"` and `File` are acceptable. | `Variant[String[1], Type[Resource]]` |
| `title` | The title, or [namevar](https://puppet.com/docs/puppet/latest/type.html#namevars-and-titles), of the resource. | `String[1]` |
| `state` | The _observed state_ of the resource. This is the point-in-time state of the resource when it is queried. | `Hash[String[1], Data]` |
| `desired_state` | The _desired state_ of the resource. This is the state that you want the resource to be in. | `Hash[String[1], Data]` |
| `events` | Resource events that are generated from reports. | `Array[Hash[String[1], Data]]` | 

A `ResourceInstance` is identified by its `target`, `type`, and `title`. As
such, these three parameters _must_ be specified when creating a new
`ResourceInstance` and are immutable. Since `Target.set_resources` will
automatically set the `target` when passing a hash of parameters, the `target`
parameter can be ommitted.

The `state`, `desired_state`, and `events` parameters are optional when creating
a `ResourceInstance`. If you do not specify `state` and `desired_state`, they
default to empty hashes, while `events` defaults to an empty array. You can
modify each of these attributes during the lifetime of the `ResourceInstance`
using [the data type's functions](bolt_types_reference.md#resourceinstance).

### Functions

The `ResourceInstance` data type has several built-in functions. These range
from accessing the object's attributes to modifying and overwriting state. For a
full list of the available functions, see [Bolt data
types](bolt_types_reference.md#resourceinstance).

### Example usage

You can easily set a resource on a set of targets. For example, if you want to
ensure that a file is present on each target:

```ruby
$resource = {
  'type'  => File,
  'title' => '/etc/puppetlabs/bolt/bolt-defaults.yaml',
  'desired_state' => {
    'ensure'  => 'present',
    'content' => "..."
  }
}

$targets.each |$target| {
  $target.set_resources($resource)
}
```

You can also combine the `get_resources` plan function with
`Target.set_resources` to query resources on a target and set them on the
corresponding `Target` objects:

```ruby
$results = $targets.get_resources([Package, User])

$results.each |$result| {
  $result.target.set_resources($result['resources'])
}
```

The `set_resources` function will return an array of `ResourceInstance` objects,
which can be used to easily examine attributes for multiple resources and
perform actions based on those attributes. For example, you can iterate over an
array of resources to determine which users need to have their maxium password
age modified:

```ruby
$results = $target.get_resources(User)

$results.each |$result| {
  $resources = $result.target.set_resources($result['resources'])

  $users = $resources.filter |$resource| { $resource.state['password_max_age'] > 90 }
                     .map |$resource| { $resource.title }

  run_task('update_password_max_age', $result.target, 'users' => $users)
}
```

Apply blocks will also return results with reports. These reports have resource
data hashes that can be used to set resources on a target:

```ruby
$apply_results = apply($targets) {
  File { '/etc/puppetlabs':
    ensure => present
  }
  Package { 'openssl':
    ensure => installed
  }
}

$apply_results.each |$result| {
  $result.target.set_resources($result.report['resource_statuses'].values)
}
```

## Native SSH transport

This feature was introduced in [Bolt
2.10.0](https://github.com/puppetlabs/bolt/blob/main/CHANGELOG.md#bolt-2100-2020-05-18).

Bolt's SSH transport uses the ruby library `net-ssh`, which is a pure ruby
implementation of the SSH2 client protocol. While robust, the library lacks
support for some features and algorithms that are available in native SSH. When
you use the native SSH transport, Bolt uses the SSH executable you've
specified instead of using `net-ssh`. Essentially, using the native SSH
transport is the same as running SSH on your command line, but with Bolt
managing the connections.

To use the native SSH transport, under the `config` option in your inventory
file, set `native-ssh: true` and `ssh-command: <SSH COMMAND>`, where
`<SSH COMMAND>` is your native SSH executable.

For example:

```yaml
ssh:
  native-ssh: true
  ssh-command: 'ssh' 
```

The value of `ssh-command` can be either a string or an array, and you can
provide any command-line options to the command. Bolt appends
Bolt-configuration settings to the command, as well as the specified target,
when connecting. Not all Bolt configuration options are supported using the
native SSH transport, but you can configure most options in your OpenSSH Config.
See [Transport configuration options](bolt_transports_reference.md#ssh) for a list
of supported Bolt SSH options.

Bolt transports have two main functions: executing remotely, and copying files
to the remote targets. `ssh-command` is what configures the remote execution,
and `copy-command` configures the copy command. The default is `scp -r`, and
`rsync` is not supported at this time.

For example:
```
ssh:
  ssh-command: 'ssh'
  copy-command: 'scp -r -F ~/ssh-config/myconf'
```

### Connecting with SSH configuration not supported by net-ssh

You can use the native SSH transport to connect to targets using configuration
that isn't supported by the Ruby net-ssh library. Configure the settings for the
transport in your inventory file, or use your local SSH config. 

#### Using an inventory file to specify SSH configuration

To encrypt SSH connections using the unsupported algorithm 
`chacha20-poly1305@openssh.com`, add the SSH command and cypher
option to your inventory file: 

```
# inventory.yaml
config:
  ssh:
    ssh-command:
      - 'ssh'
      - '-o Ciphers=chacha20-poly1305@openssh.com'
```

#### Using `~/.ssh/config` to specify SSH configuration

To encrypt SSH connections using the unsupported algorithm 
`chacha20-poly1305@openssh.com`:
1. Store the following config in your SSH config at `~/.ssh/config` as:
   ```
   Ciphers+=chacha20-poly1305@openssh.com
   ```

2. In your inventory file, configure Bolt to use the SSH shell command:
   ```
   # inventory.yaml
   config:
     ssh:
       ssh-command: 'ssh'
   ```

> **Note**: While some OpenSSH config options are supported in net-ssh, such as Ciphers, the specific
> algorithms you want to use may not be supported and you will still need to use the `ssh-command`
> option to shell out to SSH. See [the net-ssh
> README](https://github.com/net-ssh/net-ssh/#supported-algorithms) for a list of supported
> algorithms.
