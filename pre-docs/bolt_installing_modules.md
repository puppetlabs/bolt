# Installing modules

Bolt is packaged with a collection of useful modules intended to support common workflows. The included modules are described in the [Puppetfile](https://github.com/puppetlabs/bolt/blob/master/Puppetfile) included in this repository. Modules and supporting documentation are publicly available on the [Puppet Forge](https://forge.puppet.com/).

**NOTE**: Bundled Forge modules are NOT PROVIDED when bolt is installed via a ruby gem. It is recommended that bolt is [installed](https://github.com/puppetlabs/bolt/blob/master/pre-docs/bolt_installing.md) as a package for most use cases.

Modules with useful task and plan content:

- [package](https://forge.puppet.com/puppetlabs/package): Install, uninstall, update, and check the status of packages.
- [service](https://forge.puppet.com/puppetlabs/service): Manage and inspect the state of services. 
- [puppet_conf](https://forge.puppet.com/puppetlabs/puppet_conf): Inspect and change the configuration options in the `puppet.conf` file.
- [facts](https://forge.puppet.com/puppetlabs/facts): Retrieve facts from specified nodes.
- [puppet_agent](https://forge.puppet.com/puppetlabs/puppet_agent): Install Puppet Agent package.

Core Puppet providers: 

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

Bolt specific modules (not available on Forge):

- [aggregate](https://github.com/puppetlabs/bolt/tree/master/modules/aggregate): Aggregate task, script or command results.
- [canary](https://github.com/puppetlabs/bolt/tree/master/modules/canary): Run action against a small number of nodes and only if it succeeds will it run on the rest.
- [puppetdb_fact](https://github.com/puppetlabs/bolt/tree/master/modules/puppetdb_fact): Collect facts for the specified nodes from the configured PuppetDB connection and stores the collected facts on the Targets.

In the case where a different version of a bundled module is desired the user can [download](#set-upbolt-to-download-and-install-modules) the desired version and override the bundled module by [configuring](https://github.com/puppetlabs/bolt/blob/master/pre-docs/bolt_configuration_options.md) the `modulepath` to point to the desired module. Modules located on bolt's `modulepath` will take precedence over bundled modules allowing users to use custom versions or override the module namespace.


## Set up Bolt to download and install modules.

Before you can use Bolt to install modules, you must first create a Puppetfile. A Puppetfile is a formatted text file that contains a list of modules and their versions. It can include modules from the Puppet Forge or a Git repository.

For modules that require Ruby gems, see [Installing Gems with Bolt Packages](bolt_installing.md#installing-gems-with-bolt-packages).

For more details about specifying modules in a Puppetfile, see the [Puppetfile documentation](https://puppet.com/docs/pe/2018.1/puppetfile.html).

1.   Create a file named Puppetfile and store it in the Boltdir, which can be a directory named Boltdir at the root of your project or a global directory in `$HOME/.puppetlabs/bolt`. 
2.   Open the Puppetfile in a text editor and add the modules and versions that you want to install. If the modules have dependencies, list those as well. 

     ```
     # Modules from the Puppet Forge.
     mod 'puppetlabs/package', '0.2.0'
     mod 'puppetlabs/service', '0.3.1'
    
     # Module from a Git repository.
     mod 'puppetlabs/puppetlabs-facter_task', git: 'git@github.com:puppetlabs/puppetlabs-facter_task.git', ref: 'master'
     ```

3.   Add any task or plan modules stored locally in Boltdir to the list. If these modules are not listed in the Puppetfile, they will be deleted. 

     ```
     mod 'myteam/app_foo', local: true
     ```

     Alternately, any modules you don't want to manage with the Puppetfile can be manually installed to a different subdirectory in the Boltdir, such as `site`.

4.   From a terminal, install the modules listed in the Puppetfile: `bolt puppetfile install`.

     By default, Bolt installs modules to the modules subdirectory inside the Boltdir. To override this location, update the modulepath setting in the Bolt config file.


