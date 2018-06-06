
# Configuring Bolt to use orchestrator

Configure Bolt to use the orchestrator API and perform actions on PE-managed nodes.

You can configure Bolt to use the orchestrator API and perform actions on
Puppet Enterprise-managed nodes. For example, you can run a remote command:

```

bolt command run hostname --nodes pcp://<master>
```

When you run Bolt plans, the plan logic is processed locally while the
corresponding commands, scripts, tasks, and file uploads run remotely via the
API.

To set up Bolt to use the orchestrator API you must do the following:

- Install the bolt_shim module in a PE environment.
- Set PE RBAC permissions for all tasks.
- Adjust the orchestrator configuration files, as needed
- View available tasks

## Install the bolt module in a PE environment

Bolt uses a task to execute commands, upload files, and run scripts over
Orchestrator. To install this task install the `puppetlabs-bolt_shim` module
from the Forge. Install the code in the same environment as the other tasks you
want to run. Use the following Puppetfile line:

```
mod 'puppetlabs-bolt_shim', '0.1.1'
```

## Assign PE RBAC permissions for all tasks

Warning: By granting users access to Bolt tasks, you give them permission to
run arbitrary commands and upload files as a super-user.

1. In the PE console, click Access control > User roles.
2. From the list of user roles, click the one you want to have Bolt task    permissions.
3. On the Permissions tab, in the Type box, select Tasks.
4. For Permission, select Run tasks, and then select `All` from the Object list.
5. Click Add permission, and then commit the change.

## Adjust the orchestrator configuration files

Set up the orchestrator API for Bolt in the same user-specified configuration
file that is used for PE client tools:

- *nix systems `/etc/puppetlabs/client-tools/orchestrator.conf`
- Windows `C:/ProgramData/PuppetLabs/client-tools/orchestrator.conf`

> Note: If you use a global configuration file stored at
> /etc/puppetlabs/client-tools/orchestrator.conf (or
> C:\ProgramData\PuppetLabs\client-tools\orchestrator.conf for Windows), copy the
> file to your home directory.  Tip: You can also configure orchestrator in the
> Bolt configuration file (~/.puppetlabs/bolt.yml) or the configuration section
> of the inventory file (~/.puppetlabs/bolt/inventory.yaml).

Bolt can be configured to connect to Orchestrator in the `pcp` section of the
bolt config file as well. This configuration will not be shared with `puppet
task`.

By default Bolt uses the production environment in PE
when running tasks. To use a different environment change the
`task-environment` setting in bolt config.

```
---
pcp:
  task-environment: development
```

## View available tasks

To view a list of available tasks from the orchestrator API, run the command
puppet task show (instead of the command bolt task show).
