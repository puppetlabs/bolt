# Installing modules

To share the Bolt plans and tasks that you've created on the Forge, you can
package them into Puppet modules. If you'd like to use a plan or task from a
module that you found on the Forge, you can use Bolt to install the module.

## Install a module

> **Before you begin**
>
> - In your Bolt project directory, create a file named `Puppetfile`. 
> - Add any modules stored locally in `modules/` to the list. For example, 
>   ```puppet
>     mod 'my_awesome_module', local: true
>   ```
>
>   **Bolt deletes any content in `modules/` that is not listed in your
>   Puppetfile.** If you want to keep the content, but you don't want to manage
>   it with the Puppetfile, move the content to a `site-modules` directory in
>   your project.

To install a module:
   1.  Open Puppetfile in a text editor and add the modules and versions that
       you want to install. If the modules have dependencies, list those as
       well. For example:
       ```puppet
       # Modules from the Puppet Forge.
       mod 'puppetlabs-apache', '4.1.0'
       mod 'puppetlabs-postgresql', '5.12.0'
       mod 'puppetlabs-puppet_conf', '0.3.0'

       # Modules from a Git repository.
       mod 'puppetlabs-haproxy', git: 'https://github.com/puppetlabs/puppetlabs-haproxy.git', ref: 'master'
       ```   
   2. Run the `bolt puppetfile install` command. Bolt installs modules to the
      first directory in the `modulepath` setting. By default, this is the
      `modules/` subdirectory inside the Bolt project directory. To override
      this location, update the `modulepath` setting in your [project configuration file](bolt_project_reference.md).

## Create a new Bolt project and install a list of modules with dependencies

If you want to get started with a new Bolt project and you need specific modules
from the Puppet Forge, you can install the modules and their dependencies with
the `bolt project init` command. 

When you use `bolt project init` along with the `--modules` flag and a
comma-separated list of Forge modules, Bolt installs the latest versions of each
module and resolves and installs all dependencies required by those modules. For
example, to create a project named `example_project` with the `apache` and
`mysql` modules installed, use the following command:

```shell
bolt project init example_project --modules puppetlabs-apache,puppetlabs-mysql
```

The project's Puppetfile lists the `apache` and `mysql` modules and all of their
dependencies:

```puppet
# example_project/Puppetfile
mod 'puppetlabs-apache', '5.5.0'
mod 'puppetlabs-mysql', '10.6.0'
mod 'puppetlabs-stdlib', '6.3.0'
mod 'puppetlabs-concat', '6.2.0'
mod 'puppetlabs-translate', '2.2.0'
mod 'puppetlabs-resource_api', '1.1.0'
mod 'puppetlabs-puppetserver_gem', '1.1.1'
```

## Packaged modules

Bolt is packaged with a collection of useful modules to support common
workflows.

This list of packaged modules is available in a
[Puppetfile](https://github.com/puppetlabs/bolt/blob/main/Puppetfile) in the
Bolt repository. The modules and supporting documentation are publicly available
on the [Puppet Forge](https://forge.puppet.com/). 

> 🔩 **Tip:** To see a list of all modules on your current module path, use
> `bolt puppetfile show-modules`.

Modules installed on your module path take precedence over packaged modules with
the same name. If you need to use a specific version of a packaged module, you
can override the packaged version by installing the module into your `modules/`
directory. If you’ve altered the module path in your Bolt configuration, and you
want to override a packaged module, your altered module path must include the
directory where you’ve installed the module.

**Note:** If you installed Bolt as a Ruby Gem, make sure you have installed
these core modules.

### Modules with useful task and plan content

-   [package](https://forge.puppet.com/puppetlabs/package): Install, uninstall,
    update, and check the status of packages.
-   [service](https://forge.puppet.com/puppetlabs/service): Manage and inspect
    the state of services.
-   [puppet_conf](https://forge.puppet.com/puppetlabs/puppet_conf): Inspect and
    change the configuration options in the `puppet.conf` file.
-   [facts](https://forge.puppet.com/puppetlabs/facts): Retrieve facts from
    specified targets.
-   [puppet_agent](https://forge.puppet.com/puppetlabs/puppet_agent): Install
    Puppet Agent package.
-   [reboot](https://forge.puppet.com/puppetlabs/reboot): Manage system reboots.


### Core Puppet providers

-   [augeas_core](https://forge.puppet.com/puppetlabs/augeas_core): Manage
    configuration files using Augeas.
-   [host_core](https://forge.puppet.com/puppetlabs/host_core): Manage host
    entries in a hosts file.
-   [scheduled_task](https://forge.puppet.com/puppetlabs/scheduled_task):
    Provider capable of using the Version 2 Windows API for task management.
-   [sshkeys_core](https://forge.puppet.com/puppetlabs/sshkeys_core): Manage
    `SSH`, `authorized_keys`, and `ssh_known_hosts` files.
-   [zfs_core](https://forge.puppet.com/puppetlabs/zfs_core): Manage `zfs` and
    `zpool` resources.
-   [cron_core](https://forge.puppet.com/puppetlabs/cron_core): Install and
    manage `cron` resources.
-   [mount_core](https://forge.puppet.com/puppetlabs/mount_core): Manage mounted
    filesystems and mount tables.
-   [selinux_core](https://forge.puppet.com/puppetlabs/selinux_core): Manage
    Security-Enhanced Linux.
-   [yumrepo_core](https://forge.puppet.com/puppetlabs/yumrepo_core): Manage
    client yum repo configurations by parsing INI configuration files.
-   [zone_core](https://forge.puppet.com/puppetlabs/zone_core): Manage Solaris
    zone resources.


### Bolt-specific modules that are not available on the Forge

-   [aggregate](https://github.com/puppetlabs/bolt/tree/main/modules/aggregate):
    Aggregate task, script or command results.
-   [canary](https://github.com/puppetlabs/bolt/tree/main/modules/canary): Run
    action against a small number of targets and only if it succeeds will it run
    on the rest.
-   [puppetdb_fact](https://github.com/puppetlabs/bolt/tree/main/modules/puppetdb_fact):
    Collect facts for the specified targets from the configured PuppetDB
    connection and stores the collected facts on the targets.

### Modules that contain helper code for writing your own tasks

-   [ruby_task_helper](https://forge.puppet.com/puppetlabs/ruby_task_helper): A
    helper for writing tasks in Ruby.
-   [python_task_helper](https://forge.puppet.com/puppetlabs/python_task_helper):
    A helper for writing tasks in Python.

📖 **Related information** 
- For modules that require Ruby Gems, see [Install Gems with Bolt
  packages](bolt_installing.md#install-gems-in-bolts-ruby-environment)
- For more details about specifying modules in a Puppetfile, see the [Puppetfile
  documentation](https://puppet.com/docs/pe/latest/puppetfile.html).
- For more information on structuring your Bolt project directory, see [Bolt
  project directories](./projects.md).  
- Search the [Puppet Forge](https://forge.puppet.com/) for plan and task
  content.
- For an example of a Puppetfile, see the [Bolt
  Puppetfile](https://github.com/puppetlabs/bolt/blob/main/Puppetfile)
