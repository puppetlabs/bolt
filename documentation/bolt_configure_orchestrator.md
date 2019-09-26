<!--This section is used in the *Bolt* docs at bolt_configure_orchestrator.html-->
# Using Bolt with Puppet Enterprise

If you're a Puppet Enterprise (PE) customer, you can configure Bolt to use the PE orchestrator and perform actions on managed nodes. Pairing PE with Bolt enables role-based access control, logging, and visual reports in the PE console.

For details about using Bolt with PE, see the [PE orchestrator documentation](https://puppet.com/docs/pe/latest/bolt_configure_orchestrator.html).

<!--The remaining content on this page is used in the *PE* docs at bolt_configure_orchestrator.html-->
# Using Bolt with orchestrator

Bolt enables running a series of tasks -- called *plans* -- to help you automate the manual work of maintaining your infrastructure. When you pair Bolt with PE, you get advanced automation with the management and logging capabilities of PE.

Bolt connects directly to remote nodes with SSH or WinRM, so you are not required to install any agent software. To learn more about Bolt, see the [Bolt documentation](https://puppet.com/docs/bolt/latest/bolt.html).

You can configure Bolt to use the orchestrator API and perform actions on managed nodes. When you run Bolt plans, the plan logic is processed locally on the node running Bolt while corresponding commands, scripts, tasks, and file uploads run remotely using the orchestrator API.

Before you can use Bolt with PE, you must [install Bolt](https://puppet.com/docs/bolt/latest/bolt_installing.html).

To set up Bolt to use the orchestrator API, you must:
- Install the bolt_shim module in a PE environment.
- Assign task permissions to a user role.
- Adjust the orchestrator configuration files, as needed.


## Install the Bolt module in a PE environment

Bolt uses a task to execute commands, upload files, and run scripts over orchestrator. To install this task, install the [puppetlabs-bolt_shim](https://forge.puppet.com/puppetlabs/bolt_shim) module from the Forge. Install the code in the same environment as the other tasks you want to run. Use the following Puppetfile line:

```
mod 'puppetlabs-bolt_shim', '0.3.0'
```

In addition to the bolt\_shim module, any task or module content you want to execute over Puppet Communications Protocol (PCP) must be present in the PE environment. For details about downloading and installing modules for Bolt, see [Set up Bolt to download and install modules](https://puppet.com/docs/bolt/latest/installing_tasks_from_the_forge.html). By allowing only content that is present in the PE environment to be executed over PCP, you maintain role-based access control over the nodes you manage in PE.

To enable the Bolt `apply` action, you must install the [puppetlabs-apply_helpers](https://forge.puppet.com/puppetlabs/apply_helpers) module. Use the following Puppetfile line:

```
mod 'puppetlabs-apply_helpers', '0.1.0'
```

**Note:** Bolt over orchestrator can require a large amount of memory to convey large messages, such as the plugins and catalogs sent by `apply`. You might need to [increase the Java heap size](https://puppet.com/docs/pe/latest/config_java_args.html#increase-the-java-heap-size-for-pe-java-services) for orchestration services.

## Assign task permissions to a user role

**Warning:** By granting users access to Bolt tasks, you give them permission to run arbitrary commands and upload files as a super-user.

1.  In the PE console, click **Access control** \> **User roles**.

2.  From the list of user roles, click the role you want to have task permissions.

3.  On the **Permissions** tab, in the **Type** box, select **Tasks**.

4.  For **Permission**, select **Run tasks**, and select **All** from the **Instance** drop-down list.

5.  Click **Add permission**, and commit the change.


## Adjust the orchestrator configuration files

Set up the orchestrator API for Bolt in the same user-specified configuration file that is used for PE client tools:

-    **\*nix systems** `/etc/puppetlabs/client-tools/orchestrator.conf`

-    **Windows** `C:/ProgramData/PuppetLabs/client-tools/orchestrator.conf`


**Note:** If you use a global configuration file stored at `/etc/puppetlabs/client-tools/orchestrator.conf` \(or `C:\ProgramData\PuppetLabs\client-tools\orchestrator.conf` for Windows\), copy the file to your home directory.

Alternatively, you can configure Bolt to connect to orchestrator in the `pcp` section of the Bolt configuration file. This configuration will not be shared with `puppet task`. By default Bolt uses the production environment in PE when running tasks. To use a different environment, change the `task-environment` setting.

```
pcp:
  task-environment: development
```

## Specify the transport

Bolt runs tasks through the PE Orchestrator when a target uses the `pcp` transport.
Specify the transport for specific nodes by using the pcp protocol in the target's
uri like `pcp://puppet.certname` or setting `transport` in a `config` section
in `inventory.yaml`. Change the default transport for all nodes by
setting `transport` in `bolt.yaml` or passing `--transport pcp` on the
commandline.

## View available tasks

To view a list of available tasks from the orchestrator API, run the command `puppet task show` \(instead of the command `bolt task show`\).
