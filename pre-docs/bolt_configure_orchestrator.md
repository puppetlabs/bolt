# Configuring Bolt to use orchestrator

Configure Bolt to use the orchestrator API and perform actions on PE-managed nodes.

You can configure Bolt to use the orchestrator API and perform actions on Puppet Enterprise-managed nodes. For example, you can run a remote command:

```
bolt command run hostname --nodes pcp://<master> 
```

When you run Bolt plans, the plan logic is processed locally while the corresponding commands, scripts, tasks, and file uploads run remotely via the API.

To set up Bolt to use the orchestrator API you must do the following:

-   Install the bolt\_shim module in a PE environment.

-   Assign task permissions to a user role.

-   Adjust the orchestrator configuration files, as needed.

-   View available tasks.


**Note:** For more information on setting up orchestrator, see the PE pages:

-    [Installing PE client tools](https://puppet.com/docs/pe/latest/installing/installing_pe_client_tools.html) 

-    [Token-based authentication](https://puppet.com/docs/pe/latest/rbac/rbac_token_auth_intro.html#token-based-authentication) 

-    [Configuring Puppet orchestrator](https://puppet.com/docs/pe/latest/orchestrator/configuring_puppet_orchestrator.html) 


## Install the Bolt module in a PE environment

Bolt uses a task to execute commands, upload files, and run scripts over orchestrator. To install this task, install the [puppetlabs-bolt_shim](https://forge.puppet.com/puppetlabs/bolt_shim) module from the Forge. Install the code in the same environment as the other tasks you want to run. Use the following Puppetfile line:

```
mod 'puppetlabs-bolt_shim', '0.2.0'
```

In addition to the bolt\_shim module, any task or module content you want to execute over PCP must be present in the PE environment. Download the modules described in [Set up Bolt to download and install modules](installing_tasks_from_the_forge.md#) and make them available in your PE environment. By only allowing content that is present in the PE environment to be executed over PCP you maintain the role based access control over the nodes you manage in PE.

The Bolt `apply` action can be enabled by installing the [puppetlabs-apply_helpers](https://forge.puppet.com/puppetlabs/apply_helpers) module. Use the following Puppetfile line:

```
mod 'puppetlabs-apply_helpers', '0.1.0'
```

The `apply_prep` helper function requires the `puppetlabs-puppet_agent` module version described in [Set up Bolt to download and install modules](installing_tasks_from_the_forge.md#).

**Note:** Bolt over orchestrator can require a large amount of memory to convey large messages, such as the plugins and catalogs sent by `apply`. The default settings might be insufficient.

## Assign task permissions to a user role

**Warning:** By granting users access to Bolt tasks, you give them permission to run arbitrary commands and upload files as a super-user.

1.  In the PE console, click **Access control** \> **User roles**.

2.  From the list of user roles, click the one you want to have task permissions.

3.  On the **Permissions** tab, in the **Type** box, select **Tasks**.

4.  For **Permission**, select **Run tasks**, and then select **All** from the **Instance** drop-down list.

5.  Click **Add permission**, and then commit the change.


## Adjust the orchestrator configuration files

Set up the orchestrator API for Bolt in the same user-specified configuration file that is used for PE client tools:

-    **\*nix systems** `/etc/puppetlabs/client-tools/orchestrator.conf` 

-    **Windows** `C:/ProgramData/PuppetLabs/client-tools/orchestrator.conf` 


**Note:** If you use a global configuration file stored at `/etc/puppetlabs/client-tools/orchestrator.conf` \(or `C:\ProgramData\PuppetLabs\client-tools\orchestrator.conf` for Windows\), copy the file to your home directory.

**Tip:** You can also configure orchestrator in the Bolt configuration file \(`~/.puppetlabs/bolt/bolt.yaml`\) or the configuration section of the inventory file \(`~/.puppetlabs/bolt/inventory.yaml`\).

Bolt can be configured to connect to Orchestrator in the `pcp` section of the Bolt configuration file as well. This configuration will not be shared with `puppet task`. By default Bolt uses the production environment in PE when running tasks. To use a different environment change the `task-environment` setting.

```
pcp:
  task-environment: development
```

## View available tasks

To view a list of available tasks from the orchestrator API, run the command `puppet task show` \(instead of the command `bolt task show`\).

