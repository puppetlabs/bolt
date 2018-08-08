---
author: Kate Lopresti <kate.lopresti@puppet.com\>
---

# Installing modules

Set up Bolt  to download and install modules.

Before you can use Bolt to install modules, you must first create a Puppetfile. A Puppetfile is a formatted text file that contains a list of modules and their versions. It can include modules from the Puppet Forge or a Git repository.

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

4.   From a terminal, install the modules listed in the Puppetfile: `bolt puppetfile install`. 

    By default, Bolt installs modules to the modules subdirectory inside the Boltdir. To override this location, update the modulepath setting in the Bolt config file.


