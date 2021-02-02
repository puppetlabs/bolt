# Automating Windows targets

Here are some common use cases that you can accomplish with Bolt on Windows targets.

## Run a PowerShell script that restarts a service

To show you how you can use Bolt to reuse your existing PowerShell scripts, this
guide walks you through running a script with Bolt, and then converting the
script to a Bolt task and running that.

> **Before you begin**
>
> -   Ensure you’ve already [installed Bolt](bolt_installing.md#) on your
>     Windows machine.
> -   Identify a remote Windows target to work with.
> -   Ensure you have Windows credentials for the target.
> -   Ensure you have [configured Windows Remote
>     Management](https://docs.microsoft.com/en-us/windows/desktop/winrm/installation-and-configuration-for-windows-remote-management)
>     on the target.

The example script,
called [restart_service.ps1](https://gist.github.com/RandomNoun7/03dfb910e5d93fefaae6e6c2da625c44#file-restart_service-ps1),
performs common task of restarting a service on demand. The process involves
these steps:

1.  Run your PowerShell script on a Windows target.
1.  Create an inventory file to store information about the target.
1.  Convert your script to a task.
1.  Execute your new task.


### 1. Run your PowerShell script on a Windows target

First, we’ll use Bolt to run the script as-is on a single target.

1.  Create a Bolt project directory to work in, called `bolt-guide`.
1.  Copy the
    [`restart_service.ps1`](https://gist.github.com/RandomNoun7/03dfb910e5d93fefaae6e6c2da625c44#file-restart_service-ps1)
    script into `bolt-guide`.
1.  In the `bolt-guide` directory, run the `restart_service.ps1` script:
    ```
    bolt script run .\restart_service.ps1 W32Time --targets winrm://<HOSTNAME> -u Administrator -p 
    ```

    ![](restart_service.png)

    **Note:** The `-p` option prompts you to enter a password.

    By running this command, you’ve brought your script under Bolt control and
    have run it on a remote target. When you ran your script with Bolt, the
    script was transferred into a temporary directory on the remote target, it
    ran on that target, and then it was deleted from the target.


### 2. Create an inventory file to store information about your targets

To run Bolt commands against multiple targets at once, you need to provide
information about the environment by creating an [inventory
file](inventory_files.md). The inventory file is a YAML file that contains a
list of targets and target specific data.

1.  Inside the `bolt-guide` directory, use a text editor to create an
    `inventory.yaml` file and a `bolt-project.yaml` file. The `inventory.yaml` file is where
    connection information is stored, while `bolt-project.yaml` tells Bolt that the directory is a project
    and that it should load the inventory file from the directory.
1.  Inside the new `inventory.yaml` file, add the following content, listing the
    fully qualified domain names of the targets you want to run the script on,
    and replacing the credentials in the `winrm` section with those appropriate
    for your target:
    ```yaml
    groups:
      - name: windows
        targets:
          - <ADD WINDOWS SERVERS' FQDN>
          - <example.mycompany.com>
        config:
          transport: winrm
          winrm:
            user: Administrator
            password: <ADD PASSWORD>
    ```

    **Note:** To have Bolt securely prompt for a password, use the
    `--password-prompt` command-line option without supplying any value. This
    prevents the password from appearing in a process listing or on the console.
    Alternatively you can use the [`prompt` plugin](supported_plugins.md#prompt) to
    set configuration values via a prompt.

    You now have an inventory file where you can store information about your
    targets.

    You can also configure a variety of options for Bolt in `bolt-project.yaml`. For more
    information about configuration see [Configuring Bolt](configuring_bolt.md). For more
    information about Bolt projects see [Bolt projects](projects.md).


### 3. Convert your script to a Bolt task

To convert the `restart_service.ps1` script to a task, giving you the ability to
reuse and share it, create a [task metadata](writing_tasks.md#) file. Task
metadata files describe task parameters, validate input, and control how the
task runner executes the task.

**Note:** This guide shows you how to convert the script to a task by manually
creating the `.ps1` file in a directory called `tasks`. Alternatively, you can
use Puppet Development Kit (PDK), to create a task by using the [`pdk new
task`
command](https://puppet.com/docs/pdk/1.x/pdk_reference.html#pdk-new-task-command).
If you’re going to be creating a lot of tasks, using PDK is worth getting to
know. For more information, see the [PDK
documentation.](https://puppet.com/docs/pdk/1.x/pdk_overview.html)

1.  In the `bolt-guide` directory, create the following subdirectories:
    ```
    bolt-guide/
    └── modules
        └── gsg
            └── tasks
    ```
1.  Move the `restart_service.ps1` script into the `tasks` directory.
1.  In the `tasks` directory, use your text editor to create a task metadata
    file — named after the script, but with a `.json` extension, in this
    example, `restart_service.json`.
1.  Add the following content to the new task metadata file:

    ```json
    {
      "puppet_task_version": 1,
      "supports_noop": false,
      "description": "Stop or restart a service or list of services on a target.",
      "parameters": {
        "service": {
          "description": "The name of the service, or a list of service names to stop.",
          "type": "Variant[Array[String],String]"
        },
        "norestart": {
          "description": "Immediately restart the services after start.",
          "type": "Optional[Boolean]"
        }
      }
    }
    ```

1.  Save the task metadata file and navigate back to the `bolt-guide` directory.

    You now have two files in the `gsg` module’s `tasks` directory:
    `restart_service.ps1` and `restart_service.json` -- the script is officially
    converted to a Bolt task. Now that it’s converted, you no longer need to
    specify the file extension when you call it from a Bolt command.
1.  Validate that Bolt recognizes the script as a task:
    
    ```
    bolt task show gsg::restart_service
    ```

    ![](bolt_PS_2.png)

    Congratulations! You’ve successfully converted the `restart_service.ps1`
    script to a Bolt task.

1.  Execute your new task:
    ```
    bolt task run gsg::restart_service service=W32Time --targets windows
    ```

    ![](bolt_PS_3.png)

    **Note:** `--targets windows` refers to the name of the group of targets
    that you specified in your inventory file. For more information, see
    [Specify targets](running_bolt_commands.md#adding-options-to-bolt-commands).

## Deploy a package with Bolt and Chocolatey

You can use Bolt with Chocolatey to deploy a package on a Windows target. First,
use the `apply` command to install Chocolatey on the target. Next, use Puppet's
Chocolatey package provider to install the package.

This example installs the Frogsay package on a Windows target.

**Before you begin:**
- [Install Bolt](bolt_installing_modules.md)
- Configure Windows Remote Management (WinRM) on your Windows target.

To install the Frogsay package with Chocolatey:
1. Install the Chocolatey module to your Bolt project. This allows you to
   install Chocolatey to your target in the next step.
   - If you're using an existing Bolt project:
     
      _\*nix shell command_

      ```shell
      bolt module add puppetlabs-chocolatey
      ```

      _PowerShell cmdlet_

      ```powershell
      Add-BoltModule -Module puppetlabs-chocolatey
      ```

   - If you want to create a project (named `choco_project`) that includes the Chocolatey module. Create a directory named `choco_project` and run the following command inside the directory:
    
      _\*nix shell command_

      ```shell
      bolt project init chocho_project --modules puppetlabs-chocolatey
      ```

      _PowerShell cmdlet_

      ```powershell
      New-BoltProject -Name choco_project -Modules puppetlabs-chocolatey
      ```

1. Install Chocolatey on your Windows target using the `apply` command:
   
   _\*nix shell command_

    ```shell
    bolt apply -e 'include chocolatey' -t <TARGET URI> -u <USER> -p <PASSWORD> --transport winrm
    ```

    _PowerShell cmdlet_

    ```powershell
    Invoke-BoltApply -Execute "include chocolatey"  -Targets <TARGET URI> -User <USER> -Password <PASSWORD> -Transport winrm
    ```

1. Use the built-in Package task to install Frogsay on your target:
    
    _\*nix shell command_

    ```shell
    bolt task run package -t <TARGET URI> -u <USER> -p <PASSWORD> --transport winrm action=install name=frogsay
    ```

    _PowerShell cmdlet_

    ```powershell
    Invoke-BoltTask -Name package -Targets <TARGET URI> -User <USER> -Password <PASSWORD> -Transport winrm action=install name=frogsay
    ```     

1. Run `frogsay` on your target to test:
   
   _\*nix shell command_

   ```shell
   bolt command run 'frogsay ribbit' -t <TARGET URI> -u <USER> -p <PASSWORD> --transport winrm
   ```

   _PowerShell cmdlet_

   ```powershell
   Invoke-BoltCommand 'frogsay ribbit' -Targets <TARGET URI> -User <USER> -Password <PASSWORD> -Transport winrm
   ``` 
  
   Your output should look something like this:
   ```shell
   Started on example.windowstarget.net...
   Finished on example.windowstarget.net:
      STDOUT:

                WORRIED ABOUT LONG LINES? FROG CAN HOLD YOUR PLACE FOR UP TO 65534
                SECONDS BEFORE IT FORGETS WHAT IT'S DOING AND HOPS AWAY.
                /
          @..@
        (----)
        ( >__< )
        ^^ ~~ ^^
   Successful on 1 target: example.windowstarget.net
   Ran on 1 target in 2.19 sec
   ```

If you need to install packages on multiple targets, create a Bolt project with
an inventory for your targets. Using an inventory allows you to group your
targets together and dramatically simplifies Bolt commands.

📖 **Related information**

- [Bolt projects](projects.md)
- [Inventory files](inventory_files.md)
- [Applying Puppet code](applying_manifest_blocks.md)

Do you have a real-world use case for Bolt that you'd like to share? Reach out to us in the #bolt
channel on [Slack](https://slack.puppet.com).