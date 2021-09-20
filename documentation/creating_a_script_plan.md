# Wrapping a script in a plan

Running commands and scripts with Bolt is awesome, but at some point you might find yourself wanting
to do more. Wrapping a script in a plan is a great way to:
- Make the script discoverable in your project. Your teammates or module users can now find the
  plan that runs a script by running `bolt plan show`, or `Get-BoltPlan` in PowerShell.
- Parameterize script arguments. Wrapping your script in a plan lets you enforce types for arguments
  to your script, and documents those parameters. Users can see how to use your script by running
  `bolt plan show <plan>`, or `Get-BoltPlan -Name <plan>` in PowerShell.
- Pass PowerShell parameters to a script with proper types.
- Log messages before or after running the script.
- Include the script as part of more complex orchestration (for example, automatically running
  some recovery commands on any targets the script fails on).

**NOTE:** The following example uses a Shell script, but the same workflow applies for any scripting
language.

Follow these steps to turn a script into a plan. This example uses a script that pulls down
an updated image for every Docker container running in a `docker-compose` project:

_update\_images.sh_
```
#!/bin/sh
for c in `docker-compose ps --services |sort`; do
  echo "redoing $c"
  docker-compose rm -s -f $c
  docker-compose pull $c
done
docker-compose up -d --remove-orphans
```

1. Create a new directory named 'manage_docker' to store your Bolt project. When you initialize 
   the project, Bolt uses the directory name as the Bolt project name.
1. Inside the 'manage_docker' directory, create a Bolt project:

   _\*nix shell command_
   ```shell
   bolt project init
   ```
   _PowerShell cmdlet_
   ```powershell
   New-BoltProject
   ```
2. Make a `scripts/` directory in your Bolt project.
3. Place the `update_images.sh` script in the `scripts/` directory.
4. Create a Bolt plan using `bolt plan new --script`.

   _\*nix shell command_
   ```
   bolt plan new manage_docker::update_images --script manage_docker/scripts/update_images.sh
   ```
   _PowerShell cmdlet_
   ```powershell
   New-BoltPlan -Name manage_docker::update_images -Script manage_docker/scripts/update_images.sh
   ```
   This command creates a Bolt YAML plan that takes a `targets` parameter, runs the script on the
   targets, and returns the result from the script run. If you'd prefer to create a Puppet language
   plan instead of YAML, you can run the same command with the `--pp` or `-Pp` option.


Et voilà! Your plan is now in `plans/update_images.yaml` in your project. You can now run your plan
with:

_\*nix shell command_
```
bolt plan run manage_docker::update_images -t <TARGETS>
```

_PowerShell cmdlet_
```powershell
Invoke-BoltPlan -Name manage_docker::update_images -Targets <TARGETS>
```

## Scripts with arguments

### As environment variables

You can pass arguments from your plan to your script as environment variables, which can be useful
for scripts with optional parameters (where ordering arguments can be hard to predict), complex
arguments, or structured data.

Modify the example script above to take a command-line argument for the directory to run
`docker-compose` from:

_update\_images.sh_
```
#!/bin/sh
if [ -n $DOCKER_COMPOSE_DIRECTORY ]
  cd $DOCKER_COMPOSE_DIRECTORY
fi
for c in `docker-compose ps --services |sort`; do
  echo "redoing $c"
  docker-compose rm -s -f $c
  docker-compose pull $c
done
docker-compose up -d --remove-orphans
```

Run this script directly with Bolt by passing the `--env-var` command-line option to set
environment variables during script execution:

_\*nix shell command_
```
bolt script run manage_docker/scripts/update_images.sh -t <TARGETS> --env-var DOCKER_COMPOSE_DIRECTORY=./docker
```

_PowerShell cmdlet_
```powershell
Invoke-BoltScript -Name manage_docker/scripts/update_images.sh -Targets <TARGETS> -EnvVar DOCKER_COMPOSE_DIRECTORY=.\docker
```

Before you pass the argument through the plan as an environment variable,
[add a plan parameter](writing_yaml_plans.md#parameters) for the argument and pass it through to the
script. In a YAML plan, this parameters key specifies a `directory` parameter for the plan:
```yaml
parameters:
  directory:
    type: Optional[String]
    default: .
    description: The directory to execute 'docker-compose' from
  targets:
    ...
```

Next set that argument as an environment variable as part of the [script
step](writing_yaml_plans.md#script_step)
```yaml
steps:
  - name: run_script
    script: manage_docker/scripts/update_images.sh
    env_vars:
      DOCKER_COMPOSE_DIRECTORY: $directory
    targets: $targets
```

And now your plan should look like this:
```yaml
description: Update Docker images
parameters:
  directory:
    type: Optional[String]
    default: .
    description: The directory to execute 'docker-compose' from
  targets:
    type: TargetSpec
    description: A list of targets to run actions on

steps:
  - name: run_script
    script: manage_docker/scripts/update_images.sh
    env_vars:
      DOCKER_COMPOSE_DIRECTORY: $directory
    targets: $targets

return: $run_script
```

You can run the plan with:

_\*nix shell command_
```
bolt plan run manage_docker::update_images -t <TARGETS> directory=./docker
```

_PowerShell cmdlet_
```powershell
Invoke-BoltPlan -Name manage_docker::update_images -Targets <TARGETS> directory=./docker
```

### As command-line arguments

Passing script arguments on the command-line through Bolt is useful for scripts with simple,
required arguments, like one or more required strings.

For example, the following script takes a command-line argument for the directory instead of an environment variable:

_update\_images.sh_
```
#!/bin/sh
cd $1
for c in `docker-compose ps --services |sort`; do
  echo "redoing $c"
  docker-compose rm -s -f $c
  docker-compose pull $c
done
docker-compose up -d --remove-orphans
```

To pass the argument to the script as part of your `manage_docker::update_images` plan, [add a
plan parameter](writing_yaml_plans.md#parameters) for the argument and pass it through to
the script. This YAML plan accepts a `directory` parameter and passes it to the `script` step:
```yaml
parameters:
  directory:
    type: Optional[String]
    default: .
    description: The directory to execute 'docker-compose' from
  targets:
    ...
```

Next, add the argument to the [script step](writing_yaml_plans.md#script_step)
```yaml
steps:
  - name: run_script
    script: manage_docker/scripts/update_images.sh
    arguments:
      - $directory
    targets: $targets
```

Now your plan should look like this:
```yaml
description: Update Docker images
parameters:
  directory:
    type: Optional[String]
    default: .
    description: The directory to execute 'docker-compose' from
  targets:
    type: TargetSpec
    description: A list of targets to run actions on

steps:
  - name: run_script
    script: manage_docker/scripts/update_images.sh
    arguments:
      - $directory
    targets: $targets

return: $run_script
```

You can run the plan with:

_\*nix shell command_
```
bolt plan run manage_docker::update_images -t <TARGETS> directory=./docker
```

_PowerShell cmdlet_
```powershell
Invoke-BoltPlan -Name manage_docker::update_images -Targets <TARGETS> directory=./docker
```

### As PowerShell parameters

PowerShell parameters are a more fine-grained way to specify inputs for PowerShell scripts than
Bash-like command-line arguments. Using PowerShell parameters is highly recommended to more easily
pass arguments on the command-line and through plans to PowerShell scripts.

For example, the following script reboots your machine and takes a `timeout` parameter to specify how
long to wait for the reboot and a `shutdown_only` parameter to tell the script not to turn the
machine back on:

_reboot.ps1_
```
[CmdletBinding()]
Param(
  [Int]$timeout = 3,
  [Boolean]$shutdown_only = $false
)
If (Test-Path -Path $env:SYSTEMROOT\sysnative\shutdown.exe) {
  $executable = "$env:SYSTEMROOT\sysnative\shutdown.exe"
}
ElseIf (Test-Path -Path $env:SYSTEMROOT\system32\shutdown.exe) {
  $executable = "$env:SYSTEMROOT\system32\shutdown.exe"
}
Else {
  $executable = "shutdown.exe"
}

# Force a minimum timeout of 3 second to allow the response to be returned.
If ($timeout -lt 3) {
  $timeout = 3
}

$reboot_param = "/r"
If ($shutdown_only) {
  $reboot_param = "/s"
}

& $executable $reboot_param /t $timeout /d p:4:1
```

After turning the script into a plan with `bolt plan new --script` or `New-BoltPlan -Script`, add
the parameters for your script to the plan:
```yaml
parameters:
  timeout:
    type: Optional[Integer]
    default: 3
    description: How long to wait for reboot before exiting
  shutdown_only:
    type: Optional[Boolean]
    default: false
    description: Whether to keep the machine shutdown (true) or bring it back up (false)
  targets:
    ...
```

Next, add the argument to the [script step](writing_yaml_plans.md#script_step)
```yaml
steps:
  - name: run_script
    script: manage_docker/scripts/reboot.ps1
    pwsh_params:
      timeout: $timeout
      shutdown_only: $shutdown_only
    targets: $targets
```

And now your plan should look like this:
```yaml
description: Reboot Windows machines
parameters:
  timeout:
    type: Optional[Integer]
    default: 3
    description: How long to wait for reboot before exiting
  shutdown_only:
    type: Optional[Boolean]
    default: false
    description: Whether to keep the machine shutdown (true) or bring it back up (false)
  targets:
    type: TargetSpec
    description: A list of targets to run actions on

steps:
  - name: run_script
    script: manage_docker/scripts/reboot.ps1
    pwsh_params:
      timeout: $timeout
      shutdown_only: $shutdown_only
    targets: $targets

return: $run_script
```

You can run the plan with:

_\*nix shell command_
```
bolt plan run manage_docker::reboot -t <TARGETS> timeout=30 shutdown_only=true
```

_PowerShell cmdlet_
```powershell
Invoke-BoltPlan -Name manage_docker::update_images -Targets <TARGETS> timeout=30 shutdown_only=true
```

## When to write a task

[Bolt tasks](tasks.md) are scripts with an optional metadata file. In general, scripts are easier to
write and debug, and you should favor them over tasks unless you need to use a [feature specific to
Bolt tasks](writing_tasks.md).

If you need to use a task, you can convert your script into a task. Writing a script 
that accepts input through environment variables makes it easier to convert into a task.

Turning your script into a task is useful if your script has:
* **Structured or typed input**: Scripts can only accept strings so if you want to pass structured objects, you
  might need turn it into a task.
* **Structured or typed output**: If the script returns structured or typed data to your plan, turn
  it into a task.
* **Multiple Files**: If your script is broken up into multiple files, run it as a task using the
  `files` option.
* **Multiple Implementations**: If you want to write multiple implementations of your script in
  different languages, write a task using the `implementations` option.
* **Noop mode**: If your script supports running with `noop`, turning it into a task allows users to
  run the script in noop mode using the `--noop` command-line option.
