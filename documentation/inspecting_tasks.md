# Inspecting tasks

Before you run a task in your environment, inspect the task to determine what
effect it has on your targets.

## Run in no operation mode

You can run some tasks in no-operation mode (`noop`) to view changes without
taking any action on your targets. This way, you ensure the tasks perform as
designed. If a task doesn't support no-operation mode, you get an error.

- _\*nix shell command_

  ```shell
  bolt task run package name=vim action=install --noop --targets example.com
  ```

- _PowerShell cmdlet_

  ```powershell
  Invoke-BoltTask -Name package -Noop --Targets example.com name=vim action=install
  ```

## Show a task list

View a list of what tasks are installed in the current modulepath. Note that
tasks marked with the `private` metadata key are not shown:

- _\*nix shell command_

  ```shell
  bolt task show
  ```

- _PowerShell cmdlet_

  ```powershell
  Get-BoltTask
  ```

## Show documentation for a task

View parameters and other details for a task, including whether a task supports
`noop`:

- _\*nix shell command_

  ```shell
  bolt task show <TASK NAME>
  ```

- _PowerShell cmdlet_

  ```powershell
  Get-BoltTask -Name <TASK NAME>
  ```

📖 **Related information**

- For more information on the modulepath, see [Modules overview](modules.md#modulepath).