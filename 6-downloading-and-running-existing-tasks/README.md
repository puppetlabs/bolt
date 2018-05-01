# Running Existing Tasks

> **Difficulty**: Intermediate

> **Time**: Approximately 10 minutes

In this exercise you will explore existing tasks, including several tasks that take advantage of Puppet under-the-hood.

> **Note:** Some of the following content will be available on The Forge soon.

- [Install Puppet using Bolt](#install-puppet-using-bolt)
- [Use package task to check status of package](#use-package-task-to-check-status-of-package)
- [Use package task to install a package](#use-package-task-to-install-a-package)
- [The Tasks Playground](#more-tips-tricks-and-ideas-on-the-tasks-playground)

# Prerequisites
Complete the following before you start this lesson:

1. [Installing Bolt](../1-installing-bolt)
1. [Setting up test nodes](../2-acquiring-nodes)
1. [Running Commands](../3-running-commands)
1. [Running Scripts](../4-running-scripts)


# Clone the control repo and configure Bolt's modulepath

These exercises use the [task-modules](https://github.com/puppetlabs/task-modules) control repository. Like many control repos this repository contains some modules committed directly in the `site` directory and manages others with a `Puppetfile`.

1. Clone the [task-modules](https://github.com/puppetlabs/task-modules) control repository.

    ```
    mkdir -p ~/.puppetlabs
    cd ~/.puppetlabs
    git clone git@github.com:puppetlabs/task-modules.git
    ```

2. Open `~/.puppetlabs/bolt.yml` and set up the bolt module path. The module path includes both modules committed directly in `site` and those managed by the puppetfile in `modules`.

    ```
    ---
    modulepath: "~/.puppetlabs/task-modules/site:~/.puppetlabs/task-modules/modules"
    # If you have to pass --no-host-key-check to skip host key verification you can
    # uncomment these lines.
    #ssh:
    #  host-key-check: false
    ```

# Install Puppet using Bolt

The [`install_puppet` task](https://github.com/puppetlabs/task-modules/blob/master/site/install_puppet/tasks/init.sh) in task-modules contains a task to install the Puppet agent package on a node. You must run this task as root. If you're not logged in as root with vagrant you'll need to tell bolt to sudo to root with the command `--run-as root`.


- Install Puppet. This process may take a while and will produce a lot of output when it finishes.
    ```
    bolt task run install_puppet -n all --run-as root
    ```
 

# Install r10k and Puppetfile modules

Committing modules directly to the control repo is useful while you develop new modules or create private modules that won't be shared. For public modules hosted either in their own repositories or on the Puppet Forge it's easier to use a Puppetfile and install them with r10k, a general purpose toolset for deploying Puppet environments and modules. 

1. install `r10k`.

    ```
    gem install r10k
    ```

2. Use r10k to install the modules in the Puppetfile `~/.puppetlabs/task-modules/Puppetfile`

    ```
    cd ~/.puppetlabs/task-modules
    r10k puppetfile install ./Puppetfile
    ```

# Inspect installed tasks

- Run the 'bolt task show' command to view a list of the tasks installed in the previous exercise.

    ```
    bolt task show
    ```
    The result:
    ```    
    apache                        Allows you to perform apache service functions
    apt                           Allows you to perform apt functions
    bootstrap                     Bootstrap a node with puppet-agent
    exec                          Executes an arbitrary shell command on the target system
    facter_task                   Inspect the value of system facts
    install_puppet                Install the puppet 5 agent package
    minifact
    mysql::sql                    Allows you to execute arbitrary SQL
    package                       Manage and inspect the state of packages
    puppet_conf                   Inspect puppet agent configuration settings
    puppet_device                 Run puppet device on a (proxy) Puppet agent
    puppeteer::apply              Run a puppet apply on agents
    puppeteer::certificate_info   Grab certificate information on agent
    puppeteer::external_fact      Add or update external facts on agents
    puppeteer::features           Query the node for what features are available
    puppeteer::providers          Query the node for what providers are available
    resource                      Inspect the value of resources
    service                       Manage and inspect the state of services
    
    ```

        
# View and use parameters for a specific task

1. Run `bolt task show package` to view the parameters that the package task uses. 

    ```
    bolt task show package
    ```
    The result:
    ```    
    package - Manage and inspect the state of packages
    
    USAGE:
    bolt task run --nodes, -n <node-name> package action=<value> name=<value> [version=<value>] [provider=<value>]
    
    PARAMETERS:
    - action: Enum['install', 'status', 'uninstall', 'upgrade']
        The operation (install, status, uninstall and upgrade) to perform on the package
    - name: String[1, default]
        The name of the package to be manipulated
    - version: Optional[String[1, default]]
        Version numbers must match the full version to install, including release if the provider uses a release moniker.
        Ranges or semver patterns are not accepted except for the gem package provider.
        For example, to install the bash package from the rpm bash-4.1.2-29.el6.x86_64.rpm, use the string '4.1.2-29.el6'.
    - provider: Optional[String[1, default]]
        The provider to use to manage or inspect the package, defaults to the system package manager
    ```
2.  Using parameters for the package task, check on the status of the bash package:

    ```
    bolt task run package action=status name=bash --nodes all
    ```
    The result:
    ```    
    Started on node1...
    Finished on node1:
      {
        "status": "up to date",
        "version": "4.2.46-29.el7_4"
      }
    Ran on 1 node in 3.81 seconds
    ```
3.  Using parameters for the package task, install the vim package across all your nodes:

    ```
    bolt task run package action=install name=vim --nodes all --run-as root
    ```
    The result:
    ```
    Started on node1...
    Finished on node1:
      {
        "status": "present",
        "version": "2:7.4.160-2.el7"
      }
    Ran on 1 node in 15.26 seconds
    ```

# More tips, tricks and ideas on the Tasks Playground

These exercises introduce you to Puppet tasks. You'll find lots more tips, tricks, examples and hacks on the [Puppet Tasks Playground](https://github.com/puppetlabs/tasks-playground).

# Next steps

Now that you know how to download and run third party tasks with Bolt you can move on to:

[Writing Plans](../7-writing-plans)
