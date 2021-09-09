# Running scripts

When you run a script on a target, Bolt copies the script from your Bolt controller to a temporary
directory on the target, runs the script, and deletes the script from the temporary directory.
You can run scripts in any language as long as the appropriate interpreter is installed on the
target's operating system. This includes any scripting language the target can run.

There are a few ways to reference scripts for Bolt to load:
- _Preferred_: Using a [Puppet file
  reference](https://puppet.com/docs/puppet/latest/types/file.html#file-attribute-source) of the
  form `<module>/scripts/myscript.sh`. Puppet file references load files from specific directories in
  modules that are on [the modulepath](modules.md#modulepath). You can load a script from the
  `files/` directory using `<module>/files/myscript.sh`, but the preferred place for scripts to be
  loaded from is the `scripts/` directory, which is referenced with `<module>/scripts/myscript.sh`.
- Use a relative path from the root of your [Bolt project](projects.md).
- Use an absolute filepath.

Using a Puppet file reference is preferred for a few reasons:
- It works using the [run_script plan function](./plan_functions.md#run_script), which might be shared
  with users on other machines that don't have the same file structure
- It works in other Bolt runners, like Puppet Enterprise
- It isn't unique to your current system, which makes documentation and plans shareable

To execute a script you'll want to specify:
- The script file reference (Puppet file reference, relative path, or absolute path)
- Any arguments the script takes
- [Bolt CLI options](bolt_command_reference.md#script-run) 

For example, the following script is named `update_images.sh` and is in a module named
`manage_docker`. The script gets an updated image for every Docker container running in a
`docker-compose` project:

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

You can run the script with:

_\*nix shell command_
```shell
bolt script run manage_docker/scripts/update_images.sh -t <TARGETS>
```

_PowerShell cmdlet_
```powershell
Invoke-BoltScript -Script manage_docker/scripts/update_images.sh -Targets <TARGETS>
```

## Passing arguments as environment variables

Say the script above is modified to read a `DOCKER_COMPOSE_DIRECTORY` environment variable and
change directories (cd) into the value:

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

You can run the script with:

_\*nix shell command_
```shell
bolt script run manage_docker/scripts/update_images.sh -t <TARGETS> --env-var DOCKER_COMPOSE_DIRECTORY=./docker
```

_PowerShell cmdlet_
```powershell
Invoke-BoltScript -Script manage_docker/scripts/update_images.sh -Targets <TARGETS> -EnvVar DOCKER_COMPOSE_DIRECTORY=.\docker
```

## Passing arguments on the command line

If your script accepts command-line arguments, like this:

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

You can run the script with:

_\*nix shell command_
```shell
bolt script run manage_docker/scripts/update_images.sh ./docker -t <TARGETS>
```

_PowerShell cmdlet_
```powershell
Invoke-BoltScript -Script manage_docker/scripts/update_images.sh .\docker -Targets <TARGETS>
```

## Passing PowerShell parameters

The following script reboots your machine. It takes a `timeout` parameter to specify how
long to wait for the reboot, and a `shutdown_only` parameter to tell the script not to turn the
machine back on. The script still lives in the `manage_docker` module.

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

You can run the script with:

_\*nix shell command_
```shell
bolt script run manage_docker/scripts/reboot.ps1 30 true -t <TARGETS>
```

_PowerShell cmdlet_
```powershell
Invoke-BoltScript -Script manage_docker/scripts/reboot.ps1 -Targets <TARGETS> -Arguments 30,$true
```

📖 **Related information**

- For information on converting your script into a plan, see [Creating a script
  plan](creating_a_script_plan.md).
- For information on Bolt project directories, see [Bolt project
  directories](projects.md).
- For more information about the modulepath, see [Modules
  overview](modules.md#modulepath).   
