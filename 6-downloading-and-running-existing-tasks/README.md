# Running Existing Tasks

> **Difficulty**: Intermediate

> **Time**: Approximately 10 minutes

In this exercise you will explore some existing tasks, including several tasks that take advantage of Puppet under-the-hood.

> **Note:** Some of the following content will be available on The Forge soon.

- [Install Puppet using Bolt](#install-puppet-using-bolt)
- [Use package task to check status of package](#use-package-task-to-check-status-of-package)
- [Use package task to install a package](#use-package-task-to-install-a-package)
- [The Tasks Playground](#more-tips-tricks-and-ideas-on-the-tasks-playground)

# Prerequisites

For the following exercises you should already have `bolt` installed and have a few nodes (either Windows or Linux) available to run commands against. The following guides will help:

1. [Installing Bolt](../1-installing-bolt)
1. [Acquiring nodes](../2-acquiring-nodes)

It is also useful to have some familiarity with running commands with `bolt` so you understand passing nodes and credentials. The following exercise is recommended:

1. [Running Commands](../3-running-commands)

# Install Puppet using Bolt

[puppet-install-shell](https://github.com/petems/puppet-install-shell) is a project to maintain a set of scripts which install Puppet on a range of different Linux flavors.

The script can be downloaded and piped to `sh` as indicated in the documentation, alternatively you can download the script locally and then use `bolt script` to upload and run it.

```
wget https://raw.githubusercontent.com/petems/puppet-install-shell/master/install_puppet_5_agent.sh
bolt script run install_puppet_5_agent.sh --nodes <nodes>
```

That should output various installation steps and result in Puppet being installed from the official Puppet packages on the target nodes. You can verify that with bolt itself.

```
$ bolt command run "/opt/puppetlabs/bin/puppet --version" --nodes <nodes>
node1:

5.2.0

Ran on 1 node in 0.68 seconds
```

# Use package task to check status of package

With Puppet installed on the node we can use some of the tasks that expose Puppet resources, like the package task.

The `package` task is one of a number of tasks written to accompany the launch of `bolt`. These tasks will shortly be available from the Forge, but for the moment you can find it in the repository for this lab. Let's download it from there:

```bash
mkdir -p modules/package/tasks
wget https://raw.githubusercontent.com/puppetlabs/tasks-hands-on-lab/master/6-downloading-and-running-existing-tasks/modules/package/tasks/init.rb
```

Or the same on Windows with PowerShell:

```powershell
mkdir modules/package/tasks
wget https://raw.githubusercontent.com/puppetlabs/tasks-hands-on-lab/master/6-downloading-and-running-existing-tasks/modules/package/tasks/init.rb --outfile modules/package/tasks/init.rb
```

Let's quickly check on the status of a specific package using `bolt`:

```
bolt task run package action=status package=bash --nodes <nodes> --modulepath ./modules
node1:

{"status":"up to date","version":"4.3-7ubuntu1.7"}

Ran on 1 node in 3.81 seconds
```

# Use package task to install a package

The package task also supports other actions, including ensuring a package is installed. Let's install a package across all of our nodes using that action:

```
bolt task run package action=install package=vim --nodes <nodes> --modulepath ./modules
node1:

{"status":"installed","version":"2:7.4.052-1ubuntu3.1"}

Ran on 1 node in 15.26 seconds
```

# More tips, tricks and ideas on the Tasks Playground

We've really only scratched the surface of Tasks in these exercises. You'll find lots more tips, tricks, examples and hacks on the [Puppet Tasks Playground](https://github.com/puppetlabs/tasks-playground).

# Next steps

Now you know how to download and run third party tasks with `bolt` you can move on to:

1. [Writing Plans](../7-writing-plans)
