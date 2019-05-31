# Installing modules

Tasks and plans are packaged in Puppet modules, so you can install them as you would any module and manage them with a Puppetfile. 

## Packaged modules

Bolt is packaged with a collection of useful modules to support common workflows.

This list of packaged modules is available in a [Puppetfile](https://github.com/puppetlabs/bolt/blob/master/Puppetfile) in the Bolt repository. The modules and supporting documentation are publicly available on the [Puppet Forge](https://forge.puppet.com/)

**NOTE**: If you installed Bolt as a Ruby Gem, make sure you have installed these core modules.

### Modules with useful task and plan content

- [package](https://forge.puppet.com/puppetlabs/package): Install, uninstall, update, and check the status of packages.
- [service](https://forge.puppet.com/puppetlabs/service): Manage and inspect the state of services.
- [puppet_conf](https://forge.puppet.com/puppetlabs/puppet_conf): Inspect and change the configuration options in the `puppet.conf` file.
- [facts](https://forge.puppet.com/puppetlabs/facts): Retrieve facts from specified nodes.
- [puppet_agent](https://forge.puppet.com/puppetlabs/puppet_agent): Install Puppet Agent package.
- [reboot](https://forge.puppet.com/puppetlabs/reboot): Manage system reboots.

### Core Puppet providers

- [augeas_core](https://forge.puppet.com/puppetlabs/augeas_core): Manage configuration files using Augeas.
- [host_core](https://forge.puppet.com/puppetlabs/host_core): Manage host entries in a hosts file.
- [scheduled_task](https://forge.puppet.com/puppetlabs/scheduled_task): Provider capable of using the more modern Version 2 Windows API for task management.
- [sshkeys_core](https://forge.puppet.com/puppetlabs/sshkeys_core): Manage `SSH` `authorized_keys`, and `ssh_known_hosts` files.
- [zfs_core](https://forge.puppet.com/puppetlabs/zfs_core): Manage `zfs` and `zpool` resources.
- [cron_core](https://forge.puppet.com/puppetlabs/cron_core): Install and manage `cron` resources.
- [mount_core](https://forge.puppet.com/puppetlabs/mount_core): Manage mounted filesystems and mount tables.
- [selinux_core](https://forge.puppet.com/puppetlabs/selinux_core): Manage Security-Enhanced Linux.
- [yumrepo_core](https://forge.puppet.com/puppetlabs/yumrepo_core): Manage client yum repo configurations by parsing INI configuration files.
- [zone_core](https://forge.puppet.com/puppetlabs/zone_core): Manage Solaris zone resources.

### Bolt specific modules that are not available on Forge

- [aggregate](https://github.com/puppetlabs/bolt/tree/master/modules/aggregate): Aggregate task, script or command results.
- [canary](https://github.com/puppetlabs/bolt/tree/master/modules/canary): Run action against a small number of nodes and only if it succeeds will it run on the rest.
- [puppetdb_fact](https://github.com/puppetlabs/bolt/tree/master/modules/puppetdb_fact): Collect facts for the specified nodes from the configured PuppetDB connection and stores the collected facts on the Targets.

### Modules that contain helper code for writing your own tasks

- [ruby_task_helper](https://forge.puppet.com/puppetlabs/ruby_task_helper): A helper for writing tasks in ruby.
- [python_task_helper](https://forge.puppet.com/puppetlabs/python_task_helper): A helper for writing tasks in python.

**Tip**: To override a packaged module with another version, download the version you want and configure your modulepath to point to it.


## Configure Bolt to download and install modules.

Before you can use Bolt to install modules, you must first create a Puppetfile. A Puppetfile is a formatted text file that contains a list of modules and their versions. It can include modules from the Puppet Forge or a Git repository.

For modules that require Ruby gems, see [Installing Gems with Bolt Packages](bolt_installing.md#installing-gems-with-bolt-packages).

For more details about specifying modules in a Puppetfile, see the [Puppetfile documentation](https://puppet.com/docs/pe/2018.1/puppetfile.html).

1.   Create a file named Puppetfile and store it in the [Bolt project directory](./bolt_project_directory.md)
2.   Open the Puppetfile in a text editor and add the modules and versions that you want to install. If the modules have dependencies, list those as well.

     ```
     # Modules from the Puppet Forge.
     mod 'puppetlabs-apache', '4.1.0'
     mod 'puppetlabs-postgresql', '5.12.1'

     # Module from a Git repository.
     mod 'puppetlabs-haproxy', git: 'https://github.com/puppetlabs/puppetlabs-haproxy.git', ref: 'master'
     ```

3.   Add any task or plan modules stored locally in `modules/` to the list. If
     these modules are not listed in the Puppetfile, they will be deleted.

     ```
     mod 'my_awesome_module', local: true
     ```

    Install any modules that you don't want to manage with the Puppetfile to a
    different subdirectory. Conventionally, `site-modules` is used for this purpose and
    is included on the default `modulepath`.

4.   From a terminal, install the modules listed in the Puppetfile: `bolt puppetfile install`.

     Bolt installs modules to the first directory in modulepath setting. By
     default this is the `modules/` subdirectory inside the bolt project
     directory. To override this location, update the modulepath setting in the
     Bolt config file.


