# Running tasks

Bolt can run Puppet tasks on remote targets without requiring any Puppet
infrastructure. 

To execute a task, specify the following:

-   The full name of the task, formatted as `<MODULE::TASK>`, or as `<MODULE>`
    for a module's main task (the `init` task).
-   Any task parameters, as `parameter=value`.
-   The targets on which to run the task and the connection protocol, with the
    `targets` command-line option.
-   (If credentials are required to connect to the target.) The username and
    password, with the `user` and `password` command-line options.

For example, to run the `sql` task from the `mysql` module on a target named
neptune:

- _\*nix shell command_

  ```shell
  bolt task run mysql::sql database=mydatabase --targets neptune sql="SHOW TABLES"
  ```

- _PowerShell cmdlet_

  ```powershell
  Invoke-BoltTask -Name mysql::sql -Targets neptune database=mydatabase sql="SHOW TABLES"
  ```

To run the main module task defined in `init`, refer to the task by the module
name only. For example, the `puppetlabs-package` module contains only one task,
defined as `init`, but this task can execute several actions. To run the
`status` action from this module to check whether the vim package is installed,
you run:

- _\*nix shell command_

  ```shell
  bolt task run package --targets neptune action=status name=vim 
  ```

- _PowerShell cmdlet_

  ```powershell
  Invoke-BoltTask -Name package -Targets neptune action=status name=vim
  ```

> 🔩 **Tip:** Bolt ships with a collection of modules that contain useful plans
> to support common workflows. For details, see [Packaged
> modules](bolt_installing_modules.md).

## Passing structured data

If one of your task or plan parameters accepts structured data like an `array` or
`hash`, it can be passed as JSON from the command line.

If a single parameter can be parsed as JSON and the parsed value matches the
parameter's type specification in the task metadata or plan definition, it can
be passed with `<PARAM>=<VALUE>` syntax. Make sure to wrap the JSON value in
single quotes to prevent `"` characters from being swallowed by the shell.

- _\*nix shell command_

  ```shell
  bolt task run mymodule::mytask --targets app1.myorg.com load_balancers='["lb1.myorg.com", "lb2.myorg.com"]'
  ```

- _PowerShell cmdlet_

  ```powershell
  Invoke-BoltTask -Name mymodule::mytask -Targets app1.myorg.com load_balancers='["lb1.myorg.com", "lb2.myorg.com"]'
  ```

If you want to pass multiple structured values or are having trouble with the
magic parsing of single parameters, you can pass a single JSON object for all
parameters with the `params` command-line option.

- _\*nix shell command_

  ```shell
  bolt task run mymodule::mytask --targets app1.myorg.com --params '{"load_balancers": ["lb1.myorg.com", "lb2.myorg.com"]}'
  ```

- _PowerShell cmdlet_

  ```powershell
  Invoke-BoltTask -Name mymodule::mytask -Targets app1.myorg.com -Params '{"load_balancers": ["lb1.myorg.com", "lb2.myorg.com"]}'
  ```

You can also load parameters from a file by putting `@` before the file name.

- _\*nix shell command_

  ```shell
  bolt task run mymodule::mytask --targets app1.myorg.com --params @param_file.json
  ```

- _PowerShell cmdlet_

  ```powershell
  Invoke-BoltTask -Name mymodule::mytask -Targets app1.myorg.com -Params '@param_file.json'
  ```

## Specifying the modulepath

In order for Bolt to find a task, the task must be in a module on the module
path. The default modulepath is `[<PROJECT DIRECTORY>/modules, <PROJECT
DIRECTORY>/site-modules]`.

The current [Bolt project](./experimental_features.md#bolt-projects) is loaded
as a standalone module at the front of the modulepath.  If you are developing a
new task, you can create a `<PROJECT DIRECTORY>/bolt-project.yaml` file, develop
your task in `<PROJECT DIRECTORY>/tasks/`, and run Bolt from the root of your
Bolt project directory to test the task. For more information, see [Bolt
projects](projects.md).

📖 **Related information**

[Bolt project directories](projects.md)
