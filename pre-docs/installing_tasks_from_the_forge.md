---
author: Jean Bond <jean@puppet.com\>
---

# Installing tasks and plans

Tasks and plans are packaged in Puppet modules, so you can install them as you would any module and manage them with a Puppetfile. 

## Installing modules

Bolt is packaged with a collection of useful modules to support common workflows.

This list of packaged modules is available in a Puppetfile in the [Bolt repository](https://github.com/puppetlabs/bolt/blob/master/Puppetfile). The modules and supporting documentation are publicly available on the [Puppet Forge](https://forge.puppet.com/).

**Note:** If you installed Bolt as a Ruby Gem, make sure you have installed these core modules.

### Modules with useful task and plan content

-   [package](https://forge.puppet.com/puppetlabs/package): Install, uninstall, update, and check the status of packages.

-   [service](https://forge.puppet.com/puppetlabs/service): Manage and inspect the state of services.

-   [puppet\_conf](https://forge.puppet.com/puppetlabs/puppet_conf): Inspect and change the configuration options in the `puppet.conf` file.

-   [facts](https://forge.puppet.com/puppetlabs/facts): Retrieve facts from specified nodes.

-   [puppet\_agent](https://forge.puppet.com/puppetlabs/puppet_agent): Install Puppet Agent package.


### Core Puppet providers

-   [augeas\_core](https://forge.puppet.com/puppetlabs/augeas_core): Manage configuration files using Augeas.

-   [host\_core](https://forge.puppet.com/puppetlabs/host_core): Manage host entries in a hosts file.

-   [scheduled\_task](https://forge.puppet.com/puppetlabs/scheduled_task): Provider capable of using the more modern Version 2 Windows API for task management.

-   [sshkeys\_core](https://forge.puppet.com/puppetlabs/sshkeys_core): Manage `SSH`, `authorized_keys`, and `ssh_known_hosts` files.

-   [zfs\_core](https://forge.puppet.com/puppetlabs/zfs_core): Manage `zfs` and `zpool` resources.

-   [cron\_core](https://forge.puppet.com/puppetlabs/cron_core): Install and manage `cron` resources.

-   [mount\_core](https://forge.puppet.com/puppetlabs/mount_core): Manage mounted filesystems and mount tables.

-   [selinux\_core](https://forge.puppet.com/puppetlabs/selinux_core): Manage Security-Enhanced Linux.

-   [yumrepo\_core](https://forge.puppet.com/puppetlabs/yumrepo_core): Manage client yum repo configurations by parsing INI configuration files.

-   [zone\_core](https://forge.puppet.com/puppetlabs/zone_core): Manage Solaris zone resources.


### Bolt specific modules that are not available on the Forge

-   - \[aggregate\]\(https://github.com/puppetlabs/bolt/tree/master/modules/aggregate\): Aggregate task, script or command results.

-   - \[canary\]\(https://github.com/puppetlabs/bolt/tree/master/modules/canary\): Run action against a small number of nodes and only if it succeeds will it run on the rest.

-   - \[puppetdb\_fact\]\(https://github.com/puppetlabs/bolt/tree/master/modules/puppetdb\_fact\): Collect facts for the specified nodes from the configured PuppetDB connection and stores the collected facts on the Targets.


**Tip:** To override a packaged module with another version, download the version you want and configure your modulepath to point to it.

**Related information**  


[Puppetfile example](https://github.com/puppetlabs/bolt/blob/master/Puppetfile)

[Puppet Forge](https://forge.puppet.com/)

[Bolt configuration options](bolt_configuration_options.md)

## Set up Bolt to download and install modules

Before you can use Bolt to install modules, you must first create a Puppetfile. A Puppetfile is a formatted text file that contains a list of modules and their versions. It can include modules from the Puppet Forge or a Git repository.

For more details about specifying modules in a Puppetfile, see the [Puppetfile documentation](https://puppet.com/docs/pe/2018.1/puppetfile.html).

1.  Create a file named Puppetfile and store it in the Boltdir, which can be a directory named Boltdir at the root of your project or a global directory in `$HOME/.puppetlabs/bolt`.
2.  Open the Puppetfile in a text editor and add the modules and versions that you want to install. If the modules have dependencies, list those as well. 

    ```
    # Modules from the Puppet Forge.
    mod 'puppetlabs-package', '0.3.0'
    mod 'puppetlabs-service', '0.4.0'
    mod 'puppetlabs-puppet_conf', '0.3.0'
    mod 'puppetlabs-facts', '0.3.1'
    
    # Modules from a Git repository.
    mod 'puppetlabs/puppetlabs-facter_task',
        git: 'git@github.com:puppetlabs/puppetlabs-facter_task.git',
        ref: 'master'
    mod 'puppet_agent',
        git: 'https://github.com/puppetlabs/puppetlabs-puppet_agent',
        ref: '319ce44a65e73bcf2712ad17be01f9636f0673c9'
    ```

3.  Add any task or plan modules stored locally in Boltdir to the list. If these modules are not listed in the Puppetfile, they will be deleted. 

    ```
    mod 'myteam/app_foo', local: true
    ```

    Alternately, any modules that you don't want to manage with the Puppetfile you can install to a different subdirectory in the Boltdir, such as `site`.

4.  From a terminal, install the modules listed in the Puppetfile: `bolt puppetfile install`. 

    By default, Bolt installs modules to the modules subdirectory inside the Boltdir. To override this location, update the modulepath setting in the Bolt config file.


