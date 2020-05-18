# Experimental features

Most larger Bolt features are released initially in an experimental or unstable state.
This allows the Bolt team to gather feedback from real users quickly while iterating on
new functionality. Almost all experimental features are eventually stabilized in future
releases. While a feature is experimental, its API may change, requiring the user to
update their code or configuration. The Bolt team attempts to make these changes painless
by providing useful warnings around breaking behavior where possible. 

## Bolt projects

This feature was introduced in [Bolt 
2.8.0](https://github.com/puppetlabs/bolt/blob/master/CHANGELOG.md#bolt-280-2020-05-05)

Bolt project directories have been around for a while in Bolt, but this release
signals a shift in the direction we're taking with them. We see Bolt projects as
a way for you to quickly create orchestration that is specific to the
infrastructure you're working with, and then commit the project directory to git
and share it with other users in your organization. 

There are some barriers around quickly creating and sharing Bolt content that
is specific to your infrastructure. Bolt's current project structure
is closely tied to Puppet modules - you put your tasks and plans in child
directories of `site-modules` and Bolt loads that content as a module. This is
fine if your aim is to share your content on the forge or use it
programmatically, but in cases where you're looking to share orchestration that
is specific to your infrastructure, it's not always necessary, and can be cumbersome to get going quickly. 

We also needed a way for content authors to whitelist the plans and tasks that
they've created, so that when they share the content with other users, those
users can run `bolt plan show` or `bolt task show` from the project directory
and be presented with a list of only the content they need to see. 

### Using Bolt projects

Before your begin, make sure you've [updated Bolt to version 2.8.0 or
higher](./bolt_installing.md).

> **Remember:** This feature is experimental and is subject to possible breaking
> changes between minor Bolt releases.

To get started with a Bolt project:
1. Create a Bolt project:
   - To create a fresh project directory, use the command `bolt project init
   <PROJECT_NAME>`
   - To turn an existing directory into a Bolt project directory, run `Bolt
     project init` from the root of the directory.   
2. Create a `bolt-project.yaml` file in the root of your Bolt project directory.
3. Develop your Bolt plans and tasks in `plans` and `tasks` directories
   in the root of the project directory.

If `bolt-project.yaml` exists at the root of a project directory, Bolt loads the
project as a module. Bolt loads tasks and plans from the `tasks` and `plans`
directories and namespaces them to the project name.

Here is an example of a project using a simplified directory structure:
```console
.
├── bolt.yaml
├── bolt-project.yaml
├── inventory.yaml
├── plans
│   └── myplan.yaml
└── tasks
    └── mytask.yaml
```

### Naming your project

If you want to set a name for your project that is different from the name of
the Bolt project directory, add a `name` key to `bolt-project.yaml` with the project
name. 

For example:
  ```yaml
  name: myproject
  ```

Project names must match the expression: `[a-z][a-z0-9_]*`. In other words, they
can contain only lowercase letters, numbers, and underscores, and begin with a 
lowercase letter.

> **Note:** Projects take precedence over installed modules of the same name.

### Whitelisting plans and tasks

To control what tasks and plans appear when your users run `bolt plan
show` or `bolt task show`, add `tasks` and `plans`
keys to your `bolt-project.yaml` and include an array of task and plan names. 

For example, if you wanted to surface a plan named `myproject::myplan`, and a
task named `myproject::mytask`, you would use the following `bolt-project.yaml` file:

```yaml
name: myproject
plans:
- myproject::myplan
tasks:
- myproject::mytask
```
If your user runs the `bolt plan show` command, they'll get similar output to this:

```console
$ bolt plan show
myproject::myplan

MODULEPATH:
/PATH/TO/BOLT_PROJECT/site

Use `bolt plan show <plan-name>` to view details and parameters for a specific plan.
```

## `ResourceInstance` data type

This feature was introduced in [Bolt
2.10.0](https://github.com/puppetlabs/bolt/blob/master/CHANGELOG.md#bolt-2100-2020-05-18).

Bolt has had a limited ability to interact with Puppet's Resource Abstraction Layer. You
could use the `apply` function to generate catalogs and return events, and the `get_resources`
plan function can be used to query resources on a target. The `ResourceInstance` data type is
the first step in enabling plan authors to build resource-based logic into their plans to
enable a discover-inspect-execute workflow for interacting with resources on remote systems.

Use the `ResourceInstance` data type is used to store information about a single resource on a
target, including its observed state, desired state, and any related events.

> **Note::** The `ResourceInstance` data type does not interact with or modify resources in
  any way. It is only used to store information about a resource.

### Creating `ResourceInstance` objects

#### `Target.set_resources()`

The recommended way to create `ResourceInstance` objects is by setting them directly on
a `Target` object using the `Target.set_resources` function. Use the function to set one or
more resources on a target at a time. You can read more about this function in
[Bolt plan functions](plan_functions.md#set_resources).

The `Target.set_resources` function can set existing `ResourceInstance` objects on a target,
or take hashes of parameters to create new `ResourceInstance` objects and automatically set
them on a target.

When setting resources using a hash of parameters, you can pass either a single hash or an
array of hashes:

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

> **Note:** When passing a data hash to `Target.set_resources`, the `target` parameter
  is **optional**. If the `target` parameter is not specified, the function automatically
  sets the target to the target the function is called on.

> **Note:** If the `target` parameter is any target other than the one you are setting the
  resource on, Bolt will raise an error.

When setting resources using existing `ResourceInstance` objects, you can pass either a single
`ResourceInstance` or an array of `ResourceInstance` objects.

```ruby
$resource = ResourceInstance.new(...)

$target.set_resources(
  Variant[ResourceInstance, Array[ResourceInstance]] resource
)
```

> **Note:** If the target for a `ResourceInstance` does not match the target it is being set
  on, Bolt will raise an error.

A target can only have a single instance of a given resource. If you set a duplicate resource 
on a target, Bolt shallow merges the `state` and `desired_state` of the duplicate resource 
with the `state` and `desired_state` of the existing resource and adds any `events` for the
duplicate resource to the existing resource.

#### `ResourceInstance.new()`

You can also create standalone `ResourceInstance` objects without setting them directly
on a target using the `new` function.

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

### Attributes

Each `ResourceInstance` has the following attributes:

| Parameter | Type | Description |
| --- | --- | --- |
| `type` | The target that the resource is for. | `Target` |
| `type` | The [type of the resource](https://puppet.com/docs/puppet/latest/type.html). This can be either the stringified name of the resource type or the actual type itself. For example, both `"file"` and `File` are acceptable. | `Variant[String[1], Type[Resource]]` |
| `title` | The title, or [namevar](https://puppet.com/docs/puppet/latest/type.html#namevars-and-titles), of the resource. | `String[1]` |
| `state` | The _observed state_ of the resource. This is the point-in-time state of the resource when it is queried. | `Hash[String[1], Data]` |
| `desired_state` | The _desired state_ of the resource. This is the state that you want the resource to be in. | `Hash[String[1], Data]` |
| `events` | Resource events that are generated from reports. | `Array[Hash[String[1], Data]]` | 

A `ResourceInstance` is identified by its `target`, `type`, and `title`. As such, these
three parameters _must_ be specified when creating a new `ResourceInstance` and are
immutable. Since `Target.set_resources` will automatically set the `target` when passing
a hash of parameters, the `target` parameter can be ommitted.

The `state`, `desired_state`, and `events` parameters are optional when creating a
`ResourceInstance`. If you do not specify `state` and `desired_state`, they default to empty
hashes, while `events` defaults to an empty array. You can modify each of these attributes
during the lifetime of the `ResourceInstance` using [the data type's
functions](bolt_types_reference.md#resourceinstance).

### Functions

The `ResourceInstance` data type has several built-in functions. These range from accessing
the object's attributes to modifying and overwriting state. For a full list of the available
functions, see [Bolt data types](bolt_types_reference.md#resourceinstance).

### Example usage

You can easily set a resource on a set of targets. For example, if you want to ensure that
a file is present on each target:

```ruby
$resource = {
  'type'  => File,
  'title' => '/etc/puppetlabs/bolt.yaml',
  'desired_state' => {
    'ensure'  => 'present',
    'content' => "..."
  }
}

$targets.each |$target| {
  $target.set_resources($resource)
}
```

You can also combine the `get_resources` plan function with `Target.set_resources` to
query resources on a target and set them on the corresponding `Target` objects:

```ruby
$results = $targets.get_resources([Package, User])

$results.each |$result| {
  $result.target.set_resources($result['resources'])
}
```

## External SSH transport

Bolt's SSH transport uses the ruby library `net-ssh`, which is a pure ruby implementation of the
SSH2 client protocol. While robust, the library lacks support for some features and algorithms that
are available in native SSH. When you use the external SSH transport, Bolt uses the SSH executable
you've specified instead of using `net-ssh`. Essentially, using the external SSH transport is the
same as running SSH on your command line, but with Bolt managing the connections.

To use the external SSH transport, set `ssh-command: <SSH>` in [bolt.yaml](configuring_bolt.md),
where <SSH> is the SSH command to run. For example:

```
ssh:
  ssh-command: 'ssh'
```

The value of `ssh-command` can be either a string or an array, and you can provide any flags to the
command. Bolt will append Bolt-configuration settings to the command, as well as the specified
target, when connecting. Not all Bolt configuration options are supported using the external SSH
transport, but you can configure most options in your OpenSSH Config. See [bolt configuration
reference](bolt_configuration_reference.md) for the list of supported Bolt SSH options.

Bolt transports have two main functions: executing remotely, and copying files to the remote targets.
`ssh-command` is what configures the remote execution, and `copy-command` configures the copy
command. The default is `scp -r`, and `rsync` is not supported at this time.

For example:
```
ssh:
  ssh-command: 'ssh'
  copy-command: 'scp -r -F ~/ssh-config/myconf'
```
