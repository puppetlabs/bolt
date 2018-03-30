
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

- Enable Bolt actions in the PE environment.
- Set PE RBAC permissions for Bolt tasks.
- Adjust the orchestrator configuration files, as needed
- View available tasks


## Enable Bolt actions in the PE environment

Install Bolt source code as a module named 'bolt' in the Puppet code used in
PE. Install the code in the same environment as the other tasks you want to
run. Use the following Puppetfile line:


```
mod 'bolt', git: 'git@github.com:puppetlabs/bolt.git', ref: '<version of bolt>'.

```

## Assign PE RBAC permissions for Bolt tasks

Warning: By granting users access to Bolt tasks, you give them permission to
run arbitrary commands and upload files as a super-user.  In the PE console,
click Access control > User roles.

#. From the list of user roles, click the one you want to have Bolt task
   permissions.
#. On the Permissions tab, in the Type box, select Tasks.
#. For Permission, select Run tasks, and then select bolt from the Object list.
#. Click Add permission, and then commit the change.


## Adjust the orchestrator configuration files

By default Bolt uses the production environment in PE when running tasks. You
can configure it to use a different environment via the task-environment config
setting.

```

pcp:
  task-environment: development
```

Set up the orchestrator API for Bolt in the same user-specified configuration file that is used for PE:

- *nix systems `/etc/puppetlabs/client-tools/orchestrator.conf`
- Windows `C:/ProgramData/PuppetLabs/client-tools/orchestrator.conf`

> Note: If you use a global configuration file stored at
> /etc/puppetlabs/client-tools/orchestrator.conf (or
> C:\ProgramData\PuppetLabs\client-tools\orchestrator.conf for Windows), copy the
> file to your home directory.  Tip: You can also configure orchestrator in the
> Bolt configuration file (~/.puppetlabs/bolt.yml) or the configuration section
> of the inventory file (~/.puppetlabs/bolt/inventory.yaml).

## View available tasks

To view a list of available tasks from the orchestrator API, run the command
puppet task show (instead of the command bolt task show).
