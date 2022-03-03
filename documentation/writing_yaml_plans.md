# Writing plans in YAML

YAML plans run a list of steps in order, which allows you to define simple
workflows. Steps can contain embedded Puppet code expressions to add logic where
necessary.

## Creating a new project-level YAML plan

You can create a new project-level YAML plan in your Bolt project using a Bolt
command. The command accepts a single argument: the name of the plan.
Project-level plans must be namespaced to the project.

_\*nix shell command_

```shell
bolt plan new <PLAN NAME>
```

_PowerShell cmdlet_

```powershell
New-BoltPlan -Name <PLAN NAME>
```

For example, running `bolt plan new myproject::myplan` will result in
a directory structure similar to this:

```shell
myproject/
├── bolt-project.yaml
└── plans/
    └── myplan.yaml
```

## Naming plans

Plan names are named based on the filename of the plan, the name of the module
containing the plan, and the path to the plan within the module.

Place plan files in your module's `./plans` directory, using these file
extensions:

-   Puppet plans — `.pp`
-   YAML plans — `.yaml`, not `.yml`

Plan names are composed of two or more name segments, indicating:

-   The name of the module the plan is located in.
-   The name of the plan file, without the extension.
-   The path within the module, if the plan is in a subdirectory of `./plans`.

For example, given a module called `mymodule` with a plan defined in
`./mymodule/plans/myplan.pp`, the plan name is `mymodule::myplan`. A plan
defined in `./mymodule/plans/service/myplan.pp`would be
`mymodule::service::myplan`. This name is how you refer to the plan when you run
commands.

The plan filename `init` is special: the plan it defines is referenced using the
module name only. For example, in a module called `mymodule`, the plan defined
in `init.pp` is the `mymodule` plan.

Avoid giving plans the same names as constructs in the Puppet language. Although
plans do not share their namespace with other language constructs, giving plans
these names makes your code difficult to read.

Each plan name segment must begin with a lowercase letter and:

-   Can include lowercase letters.
-   Can include digits.
-   Can include underscores.
-   Must not be a [reserved
    word](https://docs.puppet.com/puppet/latest/lang_reserved.html).
-   Must not have the same name as any Puppet data types.
-   Namespace segments must match the following regular expression
    `\A[a-z][a-z0-9_]*\Z`


## Plan structure

YAML plans contain a list of steps and can include optional top-level keys.
The following top-level keys are available:

| Key | Type | Description | Required |
| --- | --- | --- | --- |
| `description` | `String` | The plan description. Appears in `bolt plan show <PLAN NAME>` and `Get-BoltPlan <PLAN NAME>` output. | |
| `parameters` | `Hash` | A hash of plan parameters. Each key is the name of the parameter and the value is the parameter definition. | |
| `private` | `Boolean` | Whether the plan should appear in `bolt plan show` and `Get-BoltPlan` output. | |
| `return` | `Array`, `Boolean`, `Hash`, `Number`, `String` | The value to return from the plan. Must evaluate to a valid [PlanResult](bolt_types_reference.md#planresult). | |
| `steps` | `Array` | The list of steps to run. | ✓ |

## Steps

The `steps` key is an array of step objects, each of which corresponds to a
specific action to take.

When the plan runs, each step is executed in order. If a step fails the plan
halts execution and raises an error containing the result of the step that
failed.

### Message step

Use a `message` step to print a message. The step prints a message to standard
out (stdout) when using the `human` output format, and prints to standard error
(stderr) when using the `json` output format. 

Message steps support the following keys:

| Key | Type | Description | Required |
| --- | --- | --- | --- |
| `message` | `Any` | The message to print. | ✓ |

For example:

```yaml
steps:
  - message: hello world
```

You can pass variables to the message step to print them to stdout. If the
variable contains a valid plan result, Bolt formats the plan result using a JSON
representation of the result object. If the object is not a plan result, Bolt
prints the object as a string.

For information on printing a step result with `message`, see [Debugging
plans](debugging_plans.md).

### Verbose step

Use a `verbose` step to print a message in verbose mode. The step prints a message to standard
out (stdout) when using the `human` output format, and prints to standard error
(stderr) when using the `json` output format. 

Verbose steps support the following keys:

| Key | Type | Description | Required |
| --- | --- | --- | --- |
| `verbose` | `Any` | The message to print. | ✓ |

For example:

```yaml
steps:
  - verbose: hello world
```

You can pass variables to the verbose step to print them to stdout. If the 
variable is a [Bolt datatype](bolt_types_reference.md) it will be formatted 
as a Hash. Once the object is formatted, if it's a Hash or Array it is printed
as JSON, otherwise Bolt prints the object as a string.

### Command step

Use a `command` step to run a single command on a list of targets and save the
results, containing stdout, stderr, and exit code. The step fails if the exit
code of any command is non-zero.

Command steps support the following keys:

| Key | Type | Description | Required |
| --- | --- | --- | --- |
| `catch_errors` | `Boolean` | Whether to catch raised errors. If set to true, the plan continues execution if the step fails. | |
| `command` | `String` | The command to run. | ✓ |
| `description` | `String` | The step's description. Logged by Bolt when the step is run. | |
| `env_vars` | `Hash` | A map of environment variables to set on the target when running the command. | |
| `name` | `String` | The name of the variable to save the step result to. | |
| `run_as` | `String` | The user to run as when running the command on the target. Only applies to targets using a transport that supports `run-as` configuration. | |
| `targets` | `Array`, `String` | A target or list of targets to run the command on. | ✓ |

For example:

```yaml
steps:
  - command: hostname -f
    targets:
      - web1.example.com
      - web2.example.com
      - web3.example.com
    description: "Get the webserver hostnames"
```

### Task step

Use a `task` step to run a Bolt task on a list of targets and save the results.

Task steps support the following keys:

| Key | Type | Description | Required |
| --- | --- | --- | --- |
| `catch_errors` | `Boolean` | Whether to catch raised errors. If set to true, the plan continues execution if the step fails. | |
| `description` | `String` | The step's description. Logged by Bolt when the step is run. | |
| `name` | `String` | The name of the variable to save the step result to. | |
| `noop` | `Boolean` | Whether to run in no-operation mode, if available. | |
| `parameters` | `Hash` | A map of parameters to pass to the task. | |
| `run_as` | `String` | The user to run as when running the task on the target. Only applies to targets using a transport that supports `run-as` configuration. | |
| `targets` | `Array`, `String` | A target or list of targets to run the task on. | ✓ |
| `task` | `String` | The task to run. | ✓ |

For example:

```yaml
steps:
  - task: package
    targets:
      - web1.example.com
      - web2.example.com
      - web3.example.com
    description: "Check the version of the openssl package on the webservers"
    parameters:
      action: status
      name: openssl
```

### Script step

Use a `script` step to run a script on a list of targets and save the results.

The script must be in the `files/` directory of a module. The name of the script
must be specified as `<modulename>/path/to/script`, omitting the `files`
directory from the path.

Script steps support the following keys:

| Key | Type | Description | Required |
| --- | --- | --- | --- |
| `arguments` | `Array` | An array of command-line arguments to pass to the script. Cannot be used with `pwsh_params`. | |
| `catch_errors` | `Boolean` | Whether to catch raised errors. If set to true, the plan continues execution if the step fails. | |
| `description` | `String` | The step's description. Logged by Bolt when the step is run. | |
| `env_vars` | `Hash` | A map of environment variables to set on the target when running the script. | |
| `name` | `String` | The name of the variable to save the step result to. | |
| `pwsh_params` | `Hash` | A map of named parameters to pass to a PowerShell script. Cannot be used with `arguments`. | |
| `run_as` | `String` | The user to run as when running the script on the target. Only applies to targets using a transport that supports `run-as` configuration. | |
| `script` | `String` | The script to run. | ✓ |
| `targets` | `Array`, `String` | A target or list of targets to run the script on. | ✓ |

For example:

```yaml
steps:
  - script: mymodule/check_server.sh
    targets:
      - web1.example.com
      - web2.example.com
      - web3.example.com
    description: "Run mymodule/files/check_server.sh on the webservers"
    arguments:
      - "/index.html"
      - 60
```

### File download step

Use a file download step to download a file or directory from a list of targets
to a destination directory on the local host.

Files and directories are downloaded to the destination directory within a
subdirectory matching the target's URL-encoded safe name. If the destination
directory is a relative path, it will expand relative to the project's
downloads directory, `<PROJECT DIRECTORY>/downloads`.

File download steps support the following keys:

| Key | Type | Description | Required |
| --- | --- | --- | --- |
| `catch_errors` | `Boolean` | Whether to catch raised errors. If set to true, the plan continues execution if the step fails. | |
| `description` | `String` | The step's description. Logged by Bolt when the step is run. | |
| `destination` | `String` | The destination directory to download the file to. | ✓ |
| `download` | `String` | The location of the remote file to download. | ✓ |
| `name` | `String` | The name of the variable to save the step result to. | |
| `run_as` | `String` | The user to run as when downloading the file from the target. Only applies to targets using a transport that supports `run-as` configuration. | |
| `targets` | `Array`, `String` | A target or list of targets to download the file from. | ✓ |

For example:

```yaml
steps:
  - download: /etc/ssh/sshd_config
    destination: sshd_config
    targets:
      - web1.example.com
      - ssh://web2.example.com
      - web3
    description: "Download ssh daemon config from the webservers"
```

If the specified file exists on each of the targets, it would be saved to the
following locations:

- `~/.puppetlabs/bolt/downloads/sshd_config/web1.example.com/sshd_config`
- `~/.puppetlabs/bolt/downloads/sshd_config/ssh%3A%2F%2Fweb2.example.com/sshd_config`
- `~/.puppetlabs/bolt/downloads/sshd_config/web3/sshd_config`

Since files are downloaded to a directory matching the target's safe name, the
target's safe name is URL encoded to ensure it's a valid directory name.

> 🔩 **Tip:** To avoid URL encoding the target's safe name, give the target a
> simple, human-readable name in your inventory file.

### File upload step

Use a file upload step to upload a file to a specific location on a list of
targets.

The file to upload must be in the `files/` directory of a Puppet module. The
source for the file must be specified as `<modulename>/path/to/file`, omitting
the `files` directory from the path.

File upload steps support the following keys:

| Key | Type | Description | Required |
| --- | --- | --- | --- |
| `catch_errors` | `Boolean` | Whether to catch raised errors. If set to true, the plan continues execution if the step fails. | |
| `description` | `String` | The step's description. Logged by Bolt when the step is run. | |
| `destination` | `String` | The remote location to upload the file to. | ✓ |
| `name` | `String` | The name of the variable to save the step result to. | |
| `run_as` | `String` | The user to run as when uploading the file to the target. Only applies to targets using a transport that supports `run-as` configuration. | |
| `targets` | `Array`, `String` | A target or list of targets to upload the file to. | ✓ |
| `upload` | `String` | The location of the local file to upload. | ✓ |

-   `upload`: The location of the local file to be uploaded
-   `destination`: The remote location to upload the file to
-   `targets`: A target or list of targets to upload the file to

For example:

```yaml
steps:
  - upload: mymodule/motd.txt
    destination: /etc/motd
    targets:
      - web1.example.com
      - web2.example.com
      - web3.example.com
    description: "Upload motd to the webservers"
```

### Plan step

Use a `plan` step to run another plan and save its result.

Plan steps support the following keys:

| Key | Type | Description | Required |
| --- | --- | --- | --- |
| `catch_errors` | `Boolean` | Whether to catch raised errors. If set to true, the plan continues execution if the step fails. | |
| `description` | `String` | The step's description. Logged by Bolt when the step is run. | |
| `name` | `String` | The name of the variable to save the step result to. | |
| `parameters` | `Hash` | A map of parameters to pass to the plan. | |
| `plan` | `String` | The plan to run. | ✓ |
| `run_as` | `String` | The user to run as when connecting to targets. This is set for all steps or functions in the plan that connect to targets. Only applies to targets using a transport that supports `run-as` configuration. | |
| `targets` | `Array`, `String` | A target or list of targets. Passed to the plan under the `targets` parameter. | |

For example:

```yaml
steps:
  - plan: facts
    description: "Gather facts for the webservers using the built-in facts plan"
    parameters:
      targets:
        - web1.example.com
        - web2.example.com
        - web3.example.com
```

### Resources step

Use a `resources` step to apply a list of Puppet resources. A resource defines
the desired state for part of a target. Bolt ensures each resource is in its
desired state. Like the steps in a `plan`, if any resource in the list fails,
the rest are skipped.

> **Note:** For each `resources` step, Bolt executes the `apply_prep` plan function against 
> the targets specified with the `targets` field. For more information about `apply_prep`, see 
> [Applying manifest blocks](applying_manifest_blocks.md#applying-manifest-blocks-from-a-puppet-plan).

Resources steps support the following keys:

| Key | Type | Description | Required |
| --- | --- | --- | --- |
| `catch_errors` | `Boolean` | Whether to catch raised errors. If set to true, the plan continues execution if the step fails. | |
| `description` | `String` | The step's description. Logged by Bolt when the step is run. | |
| `name` | `String` | The name of the variable to save the step result to. | |
| `noop` | `Boolean` | Whether to run in no-operation mode. If set to true, applies the resources in Puppet no-operation mode, returning a report of the changes it would make while taking no action. | |
| `resources` | `Array` | An array of resources to apply. | ✓ |
| `run_as` | `String` | The user to run as when connecting to targets. Only applies to targets using a transport that supports `run-as` configuration. | |
| `targets` | `Array`, `String` | A target or list of targets to run the script on. | ✓ |

Each resource is a YAML map with a type and title, and optionally a `parameters`
key. The resource type and title can either be specified separately with the
`type` and `title` keys, or can be specified in a single line by using the type
name as a key with the title as its value.

For example:

```yaml
steps:
  - resources:
    # This resource is type 'package' and title 'nginx'
    - package: nginx
      parameters:
        ensure: latest
    # This resource is type 'service' and title 'nginx'
    - type: service
      title: nginx
      parameters:
        ensure: running
    targets:
      - web1.example.com
      - web2.example.com
      - web3.example.com
    description: "Set up nginx on the webservers"
```

### Eval step

The `eval` step evaluates an expression and saves the result in a variable. This
is useful to compute a variable to use multiple times later.

Eval steps support the following keys:

| Key | Type | Description | Required |
| --- | --- | --- | --- |
| `eval` | `Array`, `Boolean`, `Hash`, `Number`, `String` | The expression to evaluate. | ✓ |
| `name` | `String` | The name of the variable to save the step result to. | |

For example:

```yaml
parameters:
  count:
    type: Integer

steps:
  - name: double_count
    eval: $count * 2
  - task: echo
    targets: web1.example.com
    parameters:
      message: "The count is ${count}, and twice the count is ${double_count}"
```

## Parameters

Plans accept parameters with the `parameters` key. The value of `parameters` is
a map, where each key is the name of a parameter and the value is a map
describing the parameter.

Parameter values can be referenced from steps as variables.

Parameters use these fields:

-   `type`: (Optional) A valid [Puppet data type](https://puppet.com/docs/puppet/latest/lang_data.html#puppet-data-types).
    The value supplied must match the type or the plan fails.
-   `default`: (Optional) Used if no value is given for the parameter
-   `description`: (Optional)


For example, this plan accepts a `load_balancer` name as a string, two sets of
targets called `frontends` and `backends`, and a `version` string:

```yaml
parameters:
  # A simple parameter definition doesn't need a type or description
  load_balancer:
  frontends:
    type: TargetSpec
    description: "The frontend web servers"
  backends:
    type: TargetSpec
    description: "The backend application servers"
  version:
    type: String
    description: "The new application version to deploy"
```

## Private plans

As a plan author, you might not want users to run your plan directly or know it exists. This is useful
for plans that are used by other plans 'under the hood', but aren't designed to be run by a human.
Plans accept a `private` key. The value of `private` is a boolean that tells Bolt whether to display
the plan in `bolt plan show` or `Get-BoltPlan` output. Private plans are still viewable with `bolt
plan show <PLAN NAME>` and `Get-BoltPlan -Name <PLAN NAME>`, and can still be run with Bolt.

```yaml
private: true
parameters:
  targets:
    type: TargetSpec
    description: "The targets to run on"

steps:
  - command: hostname -f
    targets: $targets
```

The `private` metadata is cached in your Bolt project. Bolt updates the cache:

- When you update plans in the current Bolt project.
- When you update modules in the `<PROJECT DIRECTORY>/modules/` directory.
- When you install modules using a Bolt command that installs modules.
- When you generate Puppet types using a `generate` command. 

If you manually edit a plan that is located outside of the `<PROJECT DIRECTORY>/plans/` directory or
`<PROJECT DIRECTORY>/modules/` path, Bolt might not pick up manual edits to metadata. If your plan
still appears in the output of `bolt plan show` and `Get-BoltPlan`, clear the metadata cache by
running with the `--clear-cache` flag.

## How strings are evaluated

The behavior of strings is defined by how they're written in the plan.

`'single-quoted strings'` are treated as string literals without any
interpolation.

`"double-quoted strings"` are treated as Puppet language double-quoted strings
with variable interpolation.

`| block-style strings` are treated as expressions of arbitrary Puppet code.
Note the string itself must be on a new line after the `|` character.

`bare strings` are treated dynamically based on their content. If they begin
with a `$`, they're treated as Puppet code expressions. Otherwise, they're
treated as YAML literals.

Here's an example of different kinds of strings in use:

```yaml
parameters:
  message:
    type: String
    default: "hello"

steps:
  - eval: hello
    description: 'This will evaluate to: hello'
  - eval: $message
    description: 'This will evaluate to: hello'
  - eval: '$message'
    description: 'This will evaluate to: $message'
  - eval: "${message} world"
    description: 'This will evaluate to: hello world'
  - eval: |
      [$message, $message, $message].join(" ")
    description: 'This will evaluate to: hello hello hello'
```

## Using variables and simple expressions

Parameters and step results are available as variables during plan execution,
and they can be used to compute the value for each field of a step.

The simplest way to use a variable is to reference it directly by name. For
example, this plan takes a parameter called `targets` and passes it as the
target list to a step:

```yaml
parameters:
  targets:
    type: TargetSpec

steps:
  - command: hostname -f
    targets: $targets
```

Variables can also be interpolated into string values. The string must be
double-quoted to allow interpolation. For example:

```yaml
parameters:
  username:
    type: String

steps:
  - task: echo
    parameters:
      message: "hello ${username}"
    targets: $targets
```

Many operations can be performed on variables to compute new values for step
parameters or other fields.

### Indexing arrays or hashes

You can retrieve a value from an Array or a Hash using the `[]` operator. This
operator can also be used when interpolating a value inside a string.

```yaml
parameters:
  users:
    # Array[String] is a Puppet data type representing an array of strings
    type: Array[String]

steps:
  - task: user::add
    targets: 'host.example.com'
    parameters:
      name: $users[0]
  - task: echo
    targets: 'host.example.com'
    parameters:
      message: "hello ${users[0]}"
```

### Calling functions

You can call a built-in [Bolt function](plan_functions.md#) or [Puppet
function](https://puppet.com/docs/puppet/latest/function.html) to compute a
value.

```yaml
parameters:
  users:
    type: Array[String]

steps:
  - task: user::add
    parameters:
      name: $users.first
  - task: echo
    message: "hello ${users.join(',')}"
```

### Using code blocks

Some Puppet functions take a block of code as an argument. For instance, you can
filter an array of items based on the result of a block of code.

The result of the `filter` function is an array here, not a string, because the
expression isn't inside quotes.

```yaml
parameters:
  numbers:
    type: Array[Integer]

steps:
  - task: sum
    description: "add up the numbers > 5"
    parameters:
      indexes: $numbers.filter |$num| { $num > 5 }
```

## Connecting steps

You can connect multiple steps by using the result of one step to compute the
parameters for another step.

### `name` key

The `name` key makes its result available to later steps in a variable with that
name.

This example uses the `map` function to get the value of stdout from each
command result and then joins them into a single string separated by commas.

```yaml
parameters:
  targets:
    type: TargetSpec

steps:
  - name: hostnames
    command: hostname -f
    targets: $targets
  - task: echo
    parameters:
      message: $hostnames.map |$hostname_result| { $hostname_result['stdout'] }.join(',')
```

## Returning results

You can return a result from a plan by setting the `return` key at the top level
of the plan. When the plan finishes, the `return` key is evaluated and returned
as the result of the plan. If no `return` key is set, the plan returns `undef`.

```yaml
steps:
  - name: hostnames
    command: hostname -f
    targets: $targets

return: $hostnames.map |$hostname_result| { $hostname_result['stdout'] }
```

## Computing complex values

To compute complex values, you can use a Puppet code expression as the value of
any field of a step except the `name`.

Bolt loads the plan as a YAML data structure. As it executes each step, it
evaluates any expressions embedded in the step. Each plan parameter and the
values of every previous named step are available in scope.

This lets you take advantage of the power of Puppet language in the places it's
necessary, while keeping the rest of your plan simple.

When your plans need more sophisticated control flow or error handling beyond
running a list of steps in order, it's time to convert them to [Puppet language
plans](writing_plans.md#).

## Applying Puppet code from Puppet Forge modules

Modules downloaded from the Puppet Forge often include Puppet code that you can
use to simplify your workflow. The Puppet code in these modules can be applied
to targets from a YAML plan using the [resources step](#resources-step).

For example, if you wanted to install and configure Apache and MySQL on a group
of targets, you could download the
[apache](https://forge.puppet.com/puppetlabs/apache) and
[mysql](https://forge.puppet.com/puppetlabs/mysql) modules and apply the
`apache` and `mysql::server` classes to the targets with a resources step. You
can invoke a class as part of a resources step by using the syntax `class:
classname`.

The following YAML plan accepts a list of targets and then installs and
configures Apache and MySQL using classes from the `apache` and `mysql`
modules:

```yaml
description: Install and configure Apache and MySQL

parameters:
  targets:
    type: TargetSpec
    description: The targets to configure

steps:
  - description: Install and configure Apache and MySQL
    name: configure
    targets: $targets
    resources:
      - class: apache
      - class: mysql::server

return: $configure
```

Puppet code included in modules often accepts parameters. To set parameters,
add a map of parameter names and values under the `parameters` key for a
specific resource.

```yaml
- class: apache
  parameters:
    user: apache
    manage_user: false
```

## Converting YAML plans to Puppet language plans

You can convert a YAML plan to a Puppet language plan with the `bolt plan
convert` command.

```
bolt plan convert path/to/my/plan.yaml
```

This command takes the relative or absolute path to the YAML plan to be
converted and prints the converted Puppet language plan to stdout.

**Note:** Converting a YAML plan might result in a Puppet plan which is
syntactically correct, but behaves differently. Always manually verify a
converted Puppet language plan's functionality. There are some constructs that
do not translate from YAML plans to Puppet language plans. These are
[listed](#yaml-plan-constructs-that-cannot-be-translated-to-puppet-plans) below.
If you convert a YAML plan to Puppet and it changes behavior, [file an
issue](https://github.com/puppetlabs/bolt/issues) in Bolt's Git repo.

For example, with this YAML plan:

```yaml
# site-modules/mymodule/plans/yamlplan.yaml
parameters:
  targets:
    type: TargetSpec
steps:
  - name: run_task
    task: sample
    targets: $targets
    parameters:
      message: "hello world"
return: $run_task
```

Run the following conversion:

```console
$ bolt plan convert site-modules/mymodule/plans/yamlplan.yaml
# WARNING: This is an autogenerated plan. It might not behave as expected.
plan mymodule::yamlplan(
  TargetSpec $targets
) {
  $run_task = run_task('sample', $targets, {'message' => "hello world"})
  return $run_task
}
```

## Quirks when converting YAML plans to Puppet language plans

There are some quirks and limitations associated with converting a plan
expressed in YAML to a plan expressed in the Puppet language. In some cases it
is impossible to accurately translate from YAML to Puppet. In others, code that
is generated from the conversion is syntactically correct but not idiomatic
Puppet code.

### Named `eval` step

The `eval` step allows snippets of Puppet code to be expressed in YAML plans.
When converting a multi-line `eval` step to Puppet code and storing the result
in a variable, use the `with` lambda.

For example, here is a YAML plan with a multi-line `eval` step:

```yaml
parameters:
  foo:
    type: Optional[Integer]
    description: foo
    default: 0

steps:
  - eval: |
      $x = $foo + 1
      $x * 2
    name: eval_step

return: $eval_step
```

And here is the same plan, converted to the Puppet language:

```
plan yaml_plans::with_lambda(
  Optional[Integer] $foo = 0
) {
  $eval_step = with() || {
    $x = $foo + 1
    $x * 2
  }

  return $eval_step
}
```

Writing this plan from scratch using the Puppet language, you would probably not
use the lambda. In this example the converted Puppet code is correct, but not as
natural or readable as it could be.

### Resource step variable interpolation

When applying Puppet resources in a `resource` step, variable interpolation
behaves differently in YAML plans and Puppet language plans. For example:

```pp
plan yaml_plans::interpolation_pp() {
  apply_prep('localhost')
  $interpolation = apply('localhost') {
    file { '/tmp/foo':
      content => $facts['os']['family'],
      ensure => 'present',
    }
  }
  $file_contents = file::read('/tmp/foo')

  return $file_contents
}
```

This Puppet language plan 
- Performs `apply_prep` on the target `localhost`.
- Uses a Puppet `file` resource to write the OS family discovered from the Puppet `$facts` hash
to a temporary file.
- Reads the value written to the file and returns it.

Trying to access `$facts['os']['family']` in a YAML plan would fail because Bolt would try to resolve `$facts` as a plan variable instead of evaluating it as manifest code in an `apply` block.

### Dependency order

The resources in a `resources` list are applied in order. It is possible to set
dependencies explicitly, but when doing so you must refer to them in a
particular way. Consider the following YAML plan:

```yaml
parameters:
  targets:
    type: TargetSpec
steps:
  - name: pkg
    targets: $targets
    resources:
      - title: openssh-server
        type: package
        parameters:
          ensure: present
          before: File['/etc/ssh/sshd_config']
      - title: /etc/ssh/sshd_config
        type: file
        parameters:
          ensure: file
          mode: '0600'
          content: ''
          require: Package['openssh-server']
```

Executing this plan fails during catalog compilation because of how Bolt parses
the resources referenced in the `before` and `require` parameters. You will see
the error message `Could not find resource 'File['/etc/ssh/sshd_config']' in
parameter 'before'`. The solution is to not quote the resource titles:

```yaml
parameters:
  targets:
    type: TargetSpec
steps:
  - name: pkg
    targets: $targets
    resources:
      - title: openssh-server
        type: package
        parameters:
          ensure: present
          before: File[/etc/ssh/sshd_config]
      - title: /etc/ssh/sshd_config
        type: file
        parameters:
          ensure: file
          mode: '0600'
          content: ''
          require: Package[openssh-server]
```

In general, declare resources in order. This is an unusual example to illustrate
a case where parameter parsing leads to non-intuitive results.
