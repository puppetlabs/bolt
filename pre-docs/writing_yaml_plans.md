# Writing plans in YAML

**YAML plans are an experimental feature and may experience breaking changes in y releases**

YAML plans run a list of steps in order, which allows you to define simple workflows. Steps can contain embedded Puppet code expressions to add logic where necessary.

## Defining plans

### Plan naming

Plan names are based on the module that contains the plan, and the path to the plan in the module.

Plans files should be named `planname.yaml`. Note that the file extension must be `.yaml` and not `.yml`.

See [Naming plans](writing_plans.md) for more details about where plan files should be located.

### Plan structure

A plan is a YAML document containing a map with several keys:

`steps`: The list of steps to perform
`parameters`: The parameters accepted by the plan (optional)
`return`: The value to return from the plan (optional)

## Plan steps

The `steps` key is an array of step objects, each of which corresponds to a specific action to take.

When the plan is run, each step will be executed in order. If a step fails, the plan will halt execution and raise an error containing the result of the step that failed.

Steps can have a `name` field, which must be unique and can be used to refer to the result of the step later.

Steps can also have a `description` field to explain what the step is doing.

The other available keys depend on the kind of step.

### Command step

You can use a `command` step to run a single command on a list of targets and save the results, containing stdout, stderr and exit code.

The step will fail if the exit code of any command is non-zero.

Fields:
`command`: Which command to run
`target`: A target or list of targets to run the command on

Example:

```yaml
steps:
  - command: hostname -f
    target:
      - web1.example.com
      - web2.example.com
      - web3.example.com
    description: "Get the webserver hostnames"
```

### Task step

You can use a `task` step to run a Bolt task on a list of targets and save the results.

Fields:
`task`: Which task to run
`target`: A target or list of targets to run the task on
`parameters`: A map of parameter values to pass to the task (optional)

Example:

```yaml
steps:
  - task: package
    target:
      - web1.example.com
      - web2.example.com
      - web3.example.com
    description: "Check the version of the openssl package on the webservers"
    parameters:
      action: status
      name: openssl
```

### Script step

You can use a `script` step to run a script on a list of targets and save the results.

The script must be in the `files/` directory of a module. The name of the script should be specified as `<modulename>/path/to/script`, omitting the `files` directory from the path.

Fields:
`script`: Which script to run
`target`: A target or list of targets to run the script on
`arguments`: An array of command-line arguments to pass to the script (optional)

Example:

```yaml
steps:
  - script: mymodule/check_server.sh
    target:
      - web1.example.com
      - web2.example.com
      - web3.example.com
    description: "Run mymodule/files/check_server.sh on the webservers"
    arguments:
      - "/index.html"
      - 60
```

### File upload step

You can use a file upload step to upload a file to a specific location on a list of targets.

The file to upload must be in the `files/` directory of a Puppet module. The source for the file should be specified as `<modulename>/path/to/file`, omitting the `files` directory from the path.

Fields:
`source`: The location of the file to be uploaded
`destination`: The location where the file should be uploaded to

```yaml
steps:
  - source: mymodule/motd.txt
    destination: /etc/motd
    target:
      - web1.example.com
      - web2.example.com
      - web3.example.com
    description: "Upload motd to the webservers"
```

### Plan step

You can use a `plan` step to run another plan and save its result.

Fields:
`plan`: The name of the plan to run
`parameters`: A map of parameter values to pass to the plan (optional)

Example:

```yaml
steps:
  - plan: facts
    description: "Gather facts for the webservers using the built-in facts plan"
    parameters:
      nodes:
        - web1.example.com
        - web2.example.com
        - web3.example.com
```

## Parameters

Your plan can accept parameters with the `parameters` key. The value of `parameters` is a map, where each key is the name of a parameter and the value is a map describing the parameter. A parameter can have a `type`, a `default`, and a `description`, which are all optional.

For example, this plan accepts a `load_balancer` name as a string, two sets of nodes called `frontends` and `backends`, and a `version` string.

```yaml
parameters:
  # A simple parameter definition doesn't need a type or description
  load_balancer:
  frontends:
    type: TargetSpec
    description: "The frontend web servers"
  frontends:
    type: TargetSpec
    description: "The backend application servers"
  version:
    type: String
    description: "The new application version to deploy"
```

If a type is specified, the plan will fail if a value is supplied that doesn't match the type.

The `type` must be a valid Puppet datatype. See [Puppet's data types](https://puppet.com/docs/puppet/6.3/lang_data.html#puppet-data-types) for more information.

If the parameter specifies a `default`, it will be used if no value is given for that parameter.

Parameter values can be referenced from steps as variables.

## Using variables

Parameters and step results are available as variables during plan execution, and they can be used to compute the value for each field of a step.

### Variable references

The simplest way to use a variable is to reference it directly by name.

```yaml
parameters:
  nodes:
    type: TargetSpec

steps:
  - command: hostname -f
    target: $nodes
```

This plan takes a parameter called `nodes` and passes it as the target list to a step.

### String interpolation

Variables can also be interpolated into string values.

```yaml
parameters:
  username:
    type: String

steps:
  - task: echo
    message: "hello ${username}"
    target: $nodes
```

The string must be double-quoted to allow interpolation.

## Simple expressions

Many operations can be performed on variables to compute new values for step parameters or other fields.

### Array/Hash indexing

You can retrieve a value from an Array or a Hash using the `[]` operator.

This operator can also be used when interpolating a value inside a string.

```yaml
parameters:
  users:
    # Array[String] is a Puppet data type representing an array of strings
    type: Array[String]

steps:
  - task: user::add
    target: 'host.example.com'
    parameters:
      name: $users[0]
  - task: echo
    target: 'host.example.com'
    parameters:
      message: "hello ${users[0]}"
```

### Calling functions

You can call a Puppet function to compute a value.

See the [Bolt function reference](https://puppet.com/docs/bolt/latest/plan_functions.html) and the [Puppet function reference](https://puppet.com/docs/puppet/latest/function.html) for a list of built-in functions.

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

### Blocks

Some Puppet functions take a block of code as an argument.

For instance, you can filter an array of items based on the result of a block of code.

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

The result of the `filter` function is an Array here, not a String, because the expression isn't inside quotes.

## Connecting steps

You can connect multiple steps by using the result of one step to compute the parameters for another step.

### Using step results

If a step has a `name` key, its result will be available to later steps in a variable with that name.

```yaml
parameters:
  nodes:
    type: TargetSpec

steps:
  - name: hostnames
    command: hostname -f
    target: $nodes
  - task: echo
    parameters:
      message: $hostnames.map |$hostname_result| { $hostname_result['stdout'] }.join(',')
```

This example uses the `map` function to get the value of `stdout` from each command result and then joins them into a single string separated by commas.

### Eval step

You can use an `eval` step to evaluate an expression and save the result in a variable. This is useful to compute a variable to use multiple times later.

```yaml
parameters:
  count:
    type: Integer

steps:
  - name: double_count
    eval: $count * 2
  - task: echo
    target: web1.example.com
    parameters:
      message: "The count is ${count}, and twice the count is ${double_count}"
```

## Returning results

You can return a result from a plan by setting the `return` key at the top level of the plan. When the plan finishes, the `return` key will be evaluated and returned as the result of the plan. If no `return` key is set, the plan will return `undef`.

The `return` value can be a plain value or it can be a code expression.

Example:
```yaml
steps:
  - name: hostnames
    command: hostname -f
    target: $nodes

return: $hostnames.map |$hostname_result| { $hostname_result['stdout'] }
```

## Advanced Puppet code expressions

You can use a Puppet code expression as the value of any field of a step except the `name`. This allows for complex values to be computed.

Bolt loads the plan as a YAML data structure. As it executes each step, it evaluates any expressions embedded in the step. Each plan parameter and the values of every previous named step will be available in scope.

This lets you take advantage of the power of Puppet language in the places it's necessary, while keeping the rest of your plan simple.

## String evaluation

The behavior of strings is defined by how they are written in the plan.

`'single-quoted strings'` are treated as string literals without any interpolation.

`"double-quoted strings"` are treated as Puppet language double-quoted strings with variable interpolation.

`|
  block-style strings` are treated as expressions of arbitrary Puppet code. Note the string itself must be on a new line after the `|` character.

`bare strings` are treated dynamically based on their content. If they begin with a `$`, they are treated as Puppet code expressions. Otherwise, they are treated as YAML literals.

An example of the different kinds of strings:

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

## Migrating to Puppet plans

Once your plans need more sophisticated control flow or error handling beyond running a list of steps in order, it's time to convert them to Puppet language plans.

See [Writing plans in Puppet language](./writing_plans.html) for information about how to write Puppet plans.
