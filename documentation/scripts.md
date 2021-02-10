# Running Scripts with bolt

Bolt is a useful tool to run scripts on remote systems and share them with your
teammates.

## Adding a script to your project

While bolt can run any script putting the script in the `files/` directory of
the [project](./projects.md) or a [module](./modules.md) is preferred since it
allows it to be run from plans. The following example is intended to run from
the `my_project` project against the `target1` and `target2` targets described
in the [getting started guide](./getting_started_with_bolt.md).

Start by creating a `files/` directory at the top level of your project then
add the following script to `files/hello.sh`.

```bash
#!/usr/bin/env bash

echo 'We're running a script!'
```

Run this script on remote targets with bolt by running.

```bash
bolt script run files/hello.sh -t target1
```

Most scripts need some arguments passed to them. If the script always takes the
same required arguments they can be passed on the commandline. Create the
following script in `files/ls_script.sh`

```bash
#!/usr/bin/env bash

# The argument is quoted to avoid escaping and shell injection issues.
ls "$1"
```

The `bolt script run` command will pass any extra arguments to the script it's
running. Run the script to list the files in the `/` directory with:

```bash
bolt script run files/ls_script.sh -t target1 /
```


## Wrapping a Script in a Plan

If you want your script to be easily discoverable in your project it should be
wrapped in a plan with a single a step.

Wrap the `hello.sh` script in a plan by creating a new plan with

```
bolt plan new my_project::hello
```

This will create a skeleton plan `hello.md` in the `plans/` directory of your project.

Update the description to correctly describe the plan more accurately.

The `targets` parameter will allow the user to specify the targets the script should be run on.

The `steps` section consists of a single step called `hello_step` that
specifies which script to run. To run the hello.sh script set three values in the step.
1. Add a `name` to the step so that we can refer to it's value later.
2. Set the `script` to run. When referring to a script from a plan the `files`
   directory is implied and the path should be the name of the project(or
   module) followed by the path in the files directory. In this case that is
   `my_project/hello.sh`.
3. Set the `target` on which the script should run to the `$targets` parameter
   from the plans `parameters`.

```
steps:
  - name: hello_step
    script: my_project/hello.sh
    targets: $targets
```

The `return` section determines what value is returned from the plan. For this plan we return the value of the script run by returning `$hello_step`

After these updates the `plans/hello.yaml` should look like

```yaml
# This is the structure of a simple plan. To learn more about writing
# YAML plans, see the documentation: http://pup.pt/bolt-yaml-plans

# The description sets the description of the plan that will appear
# in 'bolt plan show' output.
description: Say Hello fom a plan

# The parameters key defines the parameters that can be passed to
# the plan.
parameters:
  targets:
    type: TargetSpec
    description: A list of targets to run actions on
    default: localhost

# The steps key defines the actions the plan will take in order.
steps:
  - name: hello_step
    script: my_project/hello.sh
    targets: $targets
```

By writing a plan bolt can document the script for users. Show the plan documentation with

````
bolt plan show my_project::hello`
```

Now Run the plan with

```
bolt plan run my_project::hello -t target1
```

## Passing arguments from a plan

There are two methods through which scripts can accept input from a plan. The
simplest is through commandline arguments but this can be challenging if there
are multiple optional arguments to the script. In most cases it's best to
update scripts for bolt so they accept input through environment variables
rather then commandline arguments. If you have existing scripts with complex
commandline invocations that you want to use with bolt see the guide on
[argument processing in plans](./complex_scripts.md)

### Using Commandline Arguments

In the case of very simple scripts with no optional arguments like the
`ls_script` written above wrapping them in a plan requires only adding the
argument the plans `parameters` and passing it correctly in the step.

Create a new plan with `bolt plan new my_project::ls_script` and update the description return section as needed.
The script step can accept an array of string arguments in the `arguments`
sections. Add a static argument `/` so that the plan always runs ls on the root
directory. When finished the plan should look like:

```yaml
# This is the structure of a simple plan. To learn more about writing
# YAML plans, see the documentation: http://pup.pt/bolt-yaml-plans

# The description sets the description of the plan that will appear
# in 'bolt plan show' output.
description: "Run 'ls' on a target"

# The parameters key defines the parameters that can be passed to
# the plan.
parameters:
  targets:
    type: TargetSpec
    description: A list of targets to run actions on
    default: localhost

# The steps key defines the actions the plan will take in order.
steps:
  - name: run_ls
    script: my_project/ls_script.sh
    targets: $targets
    arguments:
      - "/"

return: $run_ls
```

run this plan with

```
bolt plan run my_project::ls_script -t targets
```

Now add a new optional parameter `path` to the parameters section and pass it
as an argument. Use `type: String[1]` to ensure it is a non-empty string and give it a reasonable description.
Refer to the value of this parameter as `$path` in the arguments section of the
script step. When complete the plan should look like.

```
# This is the structure of a simple plan. To learn more about writing
# YAML plans, see the documentation: http://pup.pt/bolt-yaml-plans

# The description sets the description of the plan that will appear
# in 'bolt plan show' output.
description: "Run 'ls' on a target"

# The parameters key defines the parameters that can be passed to
# the plan.
parameters:
  targets:
    type: TargetSpec
    description: A list of targets to run actions on
    default: localhost
  path:
    type: String[1]
    description: The path to list the contents from.

# The steps key defines the actions the plan will take in order.
steps:
  - name: run_ls
    script: my_project/ls_script.sh
    targets: $targets
    arguments:
      - $path

return: $run_ls
```

View documentation for the plan.

`bolt plan show my_project::ls_script.yaml`

now run the plan by passing the path parameter with `path=var`

`bolt plan run my_project::ls_script -t target1 path=var`


### Using Environment Variables

If the script is primarily used with bolt it's easiest to accept input the
script as environment variables rather then commandline arguments. This makes
it easier to handle optional arguments since ordering doesn't matter.

Create new script `files/ls_env.sh` that accepts input through environment
variables instead of commandline arguments. It's a good idea to namespace these
environment variables so they don't interact with the system use `BS_` for this example.

```bash
#!/usr/bin/env bash

if [ "$BS_LONG" == "true" ]; then
  long="-l"
fi

if [ "$BS_ALL" == "true" ]; then
  all="-a"
fi

ls $long $all "$BS_PATH"
```

Run this script directly with bolt by passing the environment variables with repeated `--env-var` flags.

```
bolt script run files/ls_env.sh --env-var BS_PATH=/var -t target1 --env-var BS_ALL=true
```

Now create a new plan to wrap this script with `bolt plan new
my_project::ls_env`.  This plan should accept 2 new boolean parameters `long`
and `all` use the `Boolean` type for this. This time use the `_env_var`
`parameter` instead of `arguments` to pass the `env_vars`. The plan should look
like

```yaml
description: "Run 'ls' with options on a target"

# The parameters key defines the parameters that can be passed to
# the plan.
parameters:
  targets:
    type: TargetSpec
    description: A list of targets to run actions on
    default: localhost
  path:
    type: String[1]
    description: The path to list the contents from.
  long:
    type: Boolean
    description: Whether to use the long format
    # Create a default to make the parameter optional
    default:  false
  all:
    type: Boolean
    description: Whether to list hidden contents of the directory
    default:  false

# The steps key defines the actions the plan will take in order.
steps:
  - name: run_ls
    script: my_project/ls_env.sh
    targets: $targets
    # TODO: These are currently thrown away what should we call them?
    parameters:
      _env_vars:
        # Map the names of the parameters to the environment variables the script expects
        BS_ALL: "$all"
        BS_PATH: "$path"
        BS_LONG: "$long"

return: $run_ls
```

View bolt's documentation for this plan by running `bundle exec bolt plan show my_project::ls_env`

Now run the plan passing the `all=true` to view all contents of the directory

```
bolt plan run my_project::ls_env -t target1 path=/var all=true
```

### Using Powershell

CODEREVIEW Should this be a section under wrapping or should bash and powershell be the top level sections?

Powershell provides much better tools for specifying inputs than bash does.
When writing powershell scripts for bolt prefer params instead of args. This
allows you to easily pass the plans parameters to the script as
`powershell_params`.

Create the following script that accepts some parameters an calls `Get-ChildItem`

```
param(
  [Parameter(Mandatory=$true)]
  [String]$Path,
  [Switch]$Name
)


Get-ChildItem "-Path:$Path" "-Name:$Name"
```

You can now run this script with

```
bolt script run files/list-files.ps -t target1 "\-Path:c:\\"
```

If we want to share this script with other users it's useful to wrap it in a
plan to help with discovery, documentation and validate the inputs.

- Create a new plan with `bolt plan new my_project::list_files` and update the description return section as needed.
- Add a script step refering to the script as `my_project/list-files.ps` when running from a plan `files` is implied.
- name the step `get_child` to save it's result.
- pass the `targets` from the plan to the script step.
- Use the `ps_params` option for the script step to pass the `parameters` from the plan to the scripts `params`

when you're done the plan should look like

```
description: "Run 'Get-ChildItem' with options on a target"

# The parameters key defines the parameters that can be passed to
# the plan.
parameters:
  targets:
    type: TargetSpec
    description: A list of targets to run actions on
    default: localhost
  path:
    type: String[1]
    description: The path to list the contents from.
  name:
    type: Boolean
    description: Whether to use the long format
    # Create a default to make the parameter optional
    default:  false

# The steps key defines the actions the plan will take in order.
steps:
  - name: get_child
    script: my_project/list-files.ps
    targets: $targets
    ps_params:
      path: $path
      name: $name

return: $get_child
```
Display the documentation and usage information for the script with

```
bolt plan show my_project::list_files
```

Run the plan with

```
bolt plan run my_project::list_files -t target1 path=c:\
```

Use the name option to display on the name of files


```
bolt plan run my_project::list_files -t target1 path=c:\ name=true
```

## When to use scripts vs tasks

There are a lot of similarities between bolt's ability to run script plans like
the one above and it's ability to run tasks. In general scripts are easer to
write and debug and should be favored unless some feature of the Task API is
needed. It's always easy to convert a script into a task especially if it
accepts input through environment variables. Unless you need one of the
following features write a script.

* Typed input: Scripts can only accept strings so if you want to pass strucutred objects you may need turn it into a task.
* Structured or Typed output: If the script returns structured or typed data to your plan turn it into a task.
* Multiple Files: If your script is broken up into multiple files run it as a task using the `files` option.
* Multiple Implementations: If you want to write multiple implementations of your script in different languages write a task using the `implementations` option.
