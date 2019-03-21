# Writing plans in YAML

Plans written in YAML consist of a list of steps executed in order, which allows for workflows to be defined. Steps can contain embedded Puppet code expressions to add logic.

## Naming plans

Plan files should be named `planname.yaml`. Note that the file extension must be `.yaml` and not `.yml`.

See [Naming plans](writing_plans.md) for details about where plan files should be located.

## Plan structure

A plan is a YAML document containing a map with several keys:

`steps`: The list of steps to perform
`parameters`: The parameters accepted by the plan (optional)
`return`: The value to return from the plan (optional)

## Parameters

A plan can accept a set of parameters, specified in the `parameters` key. The value of `parameters` is a map, where each key is the name of a parameter and the value is a map describing the parameter. A parameter can have a `type`, a `default`, and a `description`.

For example, this plan accepts a `load_balancer` name as a string, and two sets of nodes called `frontends` and `backends`. It then runs a series of tasks to remove nodes from the load balancer, update the application, and then add them back to the load balancer.

```yaml
parameters:
  load_balancer:
    type: String
    description: "The application load balancer"
  # A simple parameter definition doesn't need a type or description
  frontends:
  version:
    type: String
    description: "The new application version to deploy"

steps:
  - task: mymodule::lb_remove
    target: $load_balancer
    parameters:
      frontends: $frontends
  - task: mymodule::update_frontend_app
    target: $frontends
    parameters:
      version: $version
  - task: mymodule::lb_add
    target: $load_balancer
    parameters:
      frontends: $frontends
```

The `type` must be a valid Puppet datatype. See [Puppet's data types](https://puppet.com/docs/puppet/6.3/lang_data.html#puppet-data-types) for more information.

Parameter values can be referenced from steps as Puppet variables.

## Plan steps

The `steps` key is an array of step objects, each of which corresponds to a specific action to take.

When the plan is run, each step will be executed in order. If the step has a `name` field, the result of the step will be stored in a variable with the same name as the step and can then be referenced from later steps.

If a step fails, the plan will halt execution and raise an error containing the result of the failed step.

Steps can also have a `description` field to explain what the step is doing.

The other available keys depend on the kind of step. The available steps are task, command, script, file upload, plan, and eval.

### Task step

A task step will run a task on a list of targets and return the results.

Fields:
`task`: Which task to run
`target`: A target or list of targets to run the task on
`parameters`: A map of parameter values to pass to the task (optional)

Example:

```yaml
steps:
  - task: package
    target: 'webservers'
    description: "Check the version of the openssl package on the webservers"
    parameters:
      action: status
      name: openssl
```

### Command step

A command step will run a single command on a list of targets and return the results, containing stdout, stderr and exit code. The step will error if the exit code is non-zero.

Fields:
`command`: Which command to run
`target`: A target or list of targets to run the command on

Example:

```yaml
steps:
  - command: hostname -f
    target: 'webservers'
    description: "Get the webserver hostnames"
```

### Script step

A script step will run a script on a list of targets and return the results.

The script must be in the `files/` directory of a Puppet module. The name of the script should be specified as `<modulename>/path/to/script`, omitting the `files` directory from the path.

Fields:
`script`: Which script to run
`target`: A target or list of targets to run the script on
`arguments`: An array of command-line arguments to pass to the script (optional)

Example:

```yaml
steps:
  - script: mymodule/check_server.sh
    target: 'webservers'
    description: "Run mymodule/files/check_server.sh on the webservers"
    arguments:
      - "/index.html"
      - 60
```

### File upload step

A file upload step will upload a file to a specific location on a list of targets.

The file must be in the `files/` directory of a Puppet module. The source for the file should be specified as `<modulename>/path/to/file`, omitting the `files` directory from the path.

Fields:
`source`: The location of the file to be uploaded
`destination`: The location where the file should be uploaded to

```yaml
steps:
  - source: mymodule/motd.txt
    destination: /etc/motd
    target: 'webservers'
    description: "Upload motd to the webservers"
```

Example:

```yaml
steps:

```

### Plan step

A plan step will run another plan and return the result.

Fields:
`plan`: The name of the plan to run
`parameters`: A map of parameter values to pass to the plan

Example:

```yaml
steps:
  - plan: facts
    description: "Gather facts for the webservers using the built-in facts plan"
    parameters:
      nodes: 'webservers'
```

### Eval step

An eval step will execute an arbitrary expression (usually Puppet code) and return the result. This is useful when combined with the `name` field to compute values and store them in variables.

Fields:
`eval`: The expression to be executed

Example:

```yaml
steps:
  - name: double_count
    eval: $count * 2
```

## Returning results

If the `return` key is specified, it will be evaluated after the plan finishes and used as the result of the plan. Otherwise, the plan will return `undef`.

The `return` value can be a plain value or it can be a Puppet expression.

Example:
```yaml
steps:
  - name: user_counts
    task: users::count
    target: $nodes

return: $user_counts.reduce |$sum, $result| { $sum + $result['count'] }
```

## Embedding Puppet code expressions

You can use a Puppet code expression as the value of any field of a step except the `name`. This allows steps to reference parameters as well as the result of previous steps.

Immediately before running a step, any expressions embedded in the step will be evaluated. Each plan parameter and the values of every previous named step will be available in scope.

Example:

```yaml
parameters:
  nodes:
    type: TargetSpec
  message:
    type: String

steps:
  - task: echo
    target: $nodes
    parameters:
      message: $message
```

This plan will run the `echo` task on the targets specified in the `nodes` plan parameter, passing the `message` plan parameter to the task.

You can also call Puppet functions from these expressions.

Example:

```yaml
parameters:
  message:
    type: String

steps:
  - task: echo
    target: |
      puppetdb_query('inventory[certname] { facts.osfamily = "Windows" }')
    description: "Echo the message on the nodes matching a PuppetDB query"
    parameters:
      message: $message
```

YAML strings are interpreted differently depending on how they're specified.

`'single-quoted strings'` are treated as string literals without any interpolation
`"double-quoted strings"` are treated as Puppet language double-quoted strings with Puppet variable interpolation
`|
  block-style strings` are treated as expressions of Puppet code (these may be defined with either `|` or `>`)
`bare strings` are treated as Puppet code expressions _if_ they begin with a `$` and are treated as string literals otherwise

Example:
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

### Referencing step results

If a step has a `name` key, its result will be available to later steps in a variable by that name. This can be used with an `eval` step to compute and store arbitrary values.

Example:
```yaml
parameters:
  memory:
    type: Integer

steps:
  - name: memory_limit
    eval: $memory * 2
  - name: increase_limit
    task: memory::increase_limit
    target: 'webservers'
    parameters:
      limit: $memory_limit
  - eval: $increase_limit.each |$result| { notice($result['old_limit']) }
    description: "Print the old memory limits"
```
