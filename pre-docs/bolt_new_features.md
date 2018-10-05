---
author: Jean Bond <jean@puppet.com\>
---

# New features

New features added to Bolt in the 0.x release series. 

## Show command results include path to module content \(0.24.0\)

`bolt plan show <plan>` and `bolt task show <task>` include the path to the module content. \([BOLT-841](https://tickets.puppetlabs.com/browse/BOLT-841)\)

## Support for control repo as boltdir \(0.24.0\)

Bolt now reads bolt.yaml in a current or parent directory, and interprets it as the location of a Boltdir for finding config such as inventory and facts. This enables running Bolt within common control repo layouts by adding bolt.yaml. \([BOLT-816](https://tickets.puppetlabs.com/browse/BOLT-816)\)

## Updates to Ruby and OpenSSL \(0.24.0\)

Bolt packages ship with Ruby 2.5.1 and OpenSSL 1.1.0. \([BOLT-789](https://tickets.puppetlabs.com/browse/BOLT-789)\)

## Support for different input methods for implementations \(0.24.0\)

Bolt now reads and prefers input methods defined for a particular implementation of a task. \([BOLT-758](https://tickets.puppetlabs.com/browse/BOLT-758)\)

## Support for unknown keys in task metadata \(0.24.0\)

Bolt ignores unknown keys in task metadata instead of producing an error. This allows Bolt to continue working with tasks that may use future optional features in metadata. \([BOLT-752](https://tickets.puppetlabs.com/browse/BOLT-752)\)

## Breaking change: modulepath includes paths relative to the Boltdir \(0.23.0\)

When you include relative paths \(such as "modules" or "site"\) in the modulepath setting specified in the config file, they are based on the Boltdir rather than the current working directory. As a result, you can use Boltdir between multiple users. \([BOLT-719](https://tickets.puppetlabs.com/browse/BOLT-719)\)

## Site added to end of default modulepath \(0.23.0\)

The Bolt default modulepath is now `Boltdir/modules:Boltdir/site`. This provides a directory that you can manage from a Puppetfile with `bolt puppetfile install` \(Boltdir/modules\), as well as a directory that can contain custom content that you do not manage from a Puppetfile \(Boltdir/site\). \([BOLT-766](https://tickets.puppetlabs.com/browse/BOLT-766)\)

## Define sensitive parameters \(0.22.0\)

You can define parameters as sensitive, for example, passwords and API keys. These values are masked when they appear in logs and API responses. To view them set the log file to `level: debug`. For more information, see [writing\_tasks.md\#title-1536170911349](writing_tasks.md#title-1536170911349) \([BOLT-794](https://tickets.puppetlabs.com/browse/BOLT-794)\)

## Support added for tilde character \(~\) \(0.22.0\)

You can use the tilde character \(~\) to indicate your home directory when you reference a nodes file. For example, `--nodes @~/hosts.csv`. \([BOLT-813](https://tickets.puppetlabs.com/browse/BOLT-813)\)

## Improved support for apply command \(0.21.8\)

The following enhancements have been made to the Bolt`apply` command:

-   `apply` supports resource overrides, such as `File['/tmp/foo'] { mode => '0644' }` \([BOLT-775](https://tickets.puppetlabs.com/browse/BOLT-775)\)

-   `apply` works with older releases of Puppet 4.10. \([BOLT-776](https://tickets.puppetlabs.com/browse/BOLT-776)\)

-   The `apply_prep` function supports SLES 11 and 12. \([BOLT-797](https://tickets.puppetlabs.com/browse/BOLT-797)\)


## Logging messages added to run\_plan function \(0.21.7\)

The `run_plan`function logs when a plan or sub-plan starts and finishes. This matches the behavior of other run functions. \([BOLT-797](https://tickets.puppetlabs.com/browse/BOLT-797)\)

## Install a puppet-agent \(0.21.6\)

Bolt includes a version of the puppet\_agent module with tasks to install the puppet-agent package on Windows, macOS, and many Linux variants. The `apply_prep` function makes use of this task to install Puppet. \([BOLT-615](https://tickets.puppetlabs.com/browse/BOLT-615)\)

## Call Bolt from Ruby API \(0.21.6\)

New helpers have been added to the BoltSpec that allow you to call Bolt from Ruby and better test module code from Bolt. \([BOLT-717](https://tickets.puppetlabs.com/browse/BOLT-717)\)

## Apply blocks of Puppet code to remote nodes \(0.21.6\)

Use Bolt to apply blocks of Puppet code \(manifest blocks\) to remote nodes. Similar to the `puppet apply` command, which applies a standalone Puppet manifest to a local system, the Bolt`apply` command embeds Puppet code in a plan, compiles a catalog and then applies that catalog on a target. For more information, see [Applying manifest blocks](applying_manifest_blocks.md#). \([BOLT-565](https://tickets.puppetlabs.com/browse/BOLT-565)\)

## Download and install modules \(0.21.4\)

Use  Bolt to download and install modules from the Puppet Forge or a Git repository. For instructions, see [Set up Bolt to download and install modules](installing_tasks_from_the_forge.md#). \([BOLT-523](https://tickets.puppetlabs.com/browse/BOLT-523)\)

## bolt\_spec plan helpers added to Bolt gem \(0.21.4\)

Rspec helpers for unit testing plans ship with the Bolt gem. \([BOLT-613](https://tickets.puppetlabs.com/browse/BOLT-613)\)

## Support added for Transport Layer Security \(TLS\) version 1.2 \(0.21.3\)

Bolt uses the protocol TLS 1.2 to connect to Puppet orchestrator \(the PCP transport\). This enables you to work with Bolt in Puppet Enterprise deployments that have disabled TLS 1.0. \([BOLT-686](https://tickets.puppetlabs.com/browse/BOLT-686)\)

## Command completion for bash shell available \(0.21.3\)

You can activate command completion for bash shell by using the completion include file `bolt_bash_completion.sh`. For more information see, the [Bolt README](https://github.com/puppetlabs/bolt/blob/master/README.md#on-nix) for \*nix platforms.

## Update to analytics data collection \(0.21.3\)

The number of times Bolt tasks and plans are run has been added to the usage data that Bolt collects. This does not include user-defined tasks or plans. For more information, see [Analytics data collection](bolt_installing.md#). \([BOLT-578](https://tickets.puppetlabs.com/browse/BOLT-578)\)

## Trace option added to exceptions \(0.21.1\)

Bolt supports a `--trace` option which prints a backtrace or list of calls after an exception This helps locate where errors have occurred. \([BOLT-620](https://tickets.puppetlabs.com/browse/BOLT-620)\)

## Support for Kerberos authentication \(0.21.1\)

Bolt supports Kerberos authentication for SSH connections out-of-the-box when installed using the `puppet-bolt` package. \([BOLT-617](https://tickets.puppetlabs.com/browse/BOLT-617)\)

## Features property added to inventory file \(0.21.1\)

You can store features for targets in the inventory file. \([BOLT-616](https://tickets.puppetlabs.com/browse/BOLT-616)\)

## Local default configuration directory Boltdir \(0.21.0\)

The directory Boltdir has been added as the local default configuration directory for data you supply to Bolt. By default, the configfile, inventoryfile and modules are stored in this directory. The previous configuration location `~/.puppetlab/bolt.yaml` has been deprecated in favor of `~/.puppetlabs/bolt/bolt.yaml`. For more information, see [Configuring Bolt](configuring_bolt.md). \([BOLT-503](https://tickets.puppetlabs.com/browse/BOLT-503)\)

## Output format added to analytics data collection \(0.21.0\)

The output format selected \(human-readable, JSON\) has been added to the list of usage data that  Bolt collects when run. For more information, see [Analytics data collection](bolt_installing.md#). \([BOLT-579](https://tickets.puppetlabs.com/browse/BOLT-579)\)

## Sharing executables among tasks \(0.20.7\)

Multiple task implementations can refer to the same executable file with the `_task` metaparameter. For details, see [Sharing executables](writing_tasks.md#). \([BOLT-557](https://tickets.puppetlabs.com/browse/BOLT-557)\)

## Updates to analytics data collection \(0.20.7\)

Bolt collects the following usage data when run:

-   The functions called from a plan, excluding arguments

-   The number of nodes and groups defined in the Bolt inventory file.

-   The number of nodes targeted with a Bolt command.


\([BOLT-491](https://tickets.puppetlabs.com/browse/BOLT-491), [BOLT-562](https://tickets.puppetlabs.com/browse/BOLT-562), [BOLT-564](https://tickets.puppetlabs.com/browse/BOLT-564)\)

## Analytics data collection \(0.20.6\)

Bolt collects usage data when run, including which command is run \(**no** arguments are collected\), the client operating system, and which transports used. To opt out of data collection, add`disabled: true` to `~/.puppetlabs/bolt/analytics.yaml`. For more information, see [Analytics data collection](bolt_installing.md#). \([BOLT-544](https://tickets.puppetlabs.com/browse/BOLT-544)\)

## Escalate privileges  \(0.20.6\)

The `run-as-command` has been added to escalate privileges over SSH. \([BOLT-521](https://tickets.puppetlabs.com/browse/BOLT-521)\)

## PuppetDB CLI configuration files \(0.20.6\)

Bolt loads PuppetDB CLI configuration details from global config locations. \([BOLT-547](https://tickets.puppetlabs.com/browse/BOLT-547)\)

## Plan results in Puppet orchestrator \(0.20.6\)

If Puppet orchestrator supports it, Bolt sends results of a plan run to any orchestrator instances used during the plan run. \([BOLT-547](https://tickets.puppetlabs.com/browse/BOLT-547)\)

## Tasks with multiple implementations \(0.20.5\)

Write cross-platform tasks more easily by providing multiple implementations that dispatch based on transport-specific features. For more information, see [Writing tasks](writing_tasks.md#). \([BOLT-135](https://tickets.puppetlabs.com/browse/BOLT-135)\)

## tty option available in configuration and inventory files \(0.20.5\)

You can configure `tty` in the `ssh` transport in Bolt's config file or as part of inventory config. You use `tty` to print the name of your terminal to standard output. Previously it was available only as a command-line flag. \([BOLT-555](https://tickets.puppetlabs.com/browse/BOLT-555)\)

## Bolt available from Chocolatey and Homebrew \(0.20.3\)

You can install Bolt from the package managers Chocolatey \(for Windows\) and Homebrew \(for Mac OS X. For more information, see [Installing Bolt](bolt_installing.md#). \([BOLT-464](https://tickets.puppetlabs.com/browse/BOLT-464) and [BOLT-465](https://tickets.puppetlabs.com/browse/BOLT-465)\)

## Breaking change:  Bolt packages have been renamed \(0.20.0\)

Packaged versions of Bolt have been renamed `puppet-bolt` on all platforms. This is to avoid conflicts with the bolt project on Ubuntu 18.04. For details on how this impacts installation procedures see, [Installing Bolt](bolt_installing.md#). \([BOLT-461](https://tickets.puppetlabs.com/browse/BOLT-461)\)

## puppetdb\_query added to plan language \(0.20.0\)

The `{{puppetdb_query}}` function has been added to the plan language. This relies on the PuppetDB section of the Bolt config. \([BOLT-462](https://tickets.puppetlabs.com/browse/BOLT-462)\)

## facter -p added to facts module \(0.20.0\)

The tasks for retrieving facts included with Bolt now include custom facts via `{{facter -p}}`. \([BOLT-460](https://tickets.puppetlabs.com/browse/BOLT-460)\)

## Suppress default logging notices for plans \(0.20.0\)

The function `without_default_logging` has been added to indicate that action messages be logged at the information level instead of the notice level. This is useful for plans that contain many small actions. For more information see, [Plan logging](writing_plans.md#). \([BOLT-451](https://tickets.puppetlabs.com/browse/BOLT-451)\)

-   **[New features \(0.19.x and earlier\)](bolt_new_features-019.md)**  
New features added to Bolt in the Bolt 0.6 to 0.19 release series.

