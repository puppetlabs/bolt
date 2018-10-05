---
author: Jean Bond <jean@puppet.com\>
---

# Resolved issues

Security and bug fixes in the Bolt 0.x release series.

## Facts plan should error when gathering facts fails

Facts plan will no longer hide failures to collect facts. \([BOLT-865](https://tickets.puppetlabs.com/browse/BOLT-865)\)

## Bolt cannot run multiple tasks at once on the local transport \(0.24.0\)

Bolt can now run multiple tasks at once via the local transport. \([BOLT-862](https://tickets.puppetlabs.com/browse/BOLT-862)\)

## apply\(\) loads Puppet features from the default modulepath \(0.24.0\)

The apply\(\) function incorrectly loaded module content that happened to be present on the target node. It now only loads content present on the Bolt controller. \([BOLT-857](https://tickets.puppetlabs.com/browse/BOLT-857)\)

## --run-as can corrupt task stdin over SSH \(0.23.0\)

Previously, tasks sometimes receive corrupted input when you used the escalation option `--run-as` over SSH. Tasks now reliably receive correctly-formatted JSON input. \([BOLT-854](https://tickets.puppetlabs.com/browse/BOLT-854)\)

## Passwords do not work with WinRM \(0.23.0\)

Previously, when running commands over WinRM, a UTF encoding error occurred for passwords that contained special characters, which were parsed as URL-encoded characters. This has been fixed.\([BOLT-852](https://tickets.puppetlabs.com/browse/BOLT-852)\)

## Puppet 6 Platform issues \(0.23.0\)

The recent release of Puppet 6 Platform introduced the following issues into Bolt, which have been fixed.

-   When you upgraded Windows targets to Puppet 6, Ruby tasks failed. \([BOLT-844](https://tickets.puppetlabs.com/browse/BOLT-844)\)

-   Puppet 6 moved several resource declarations from the gem to packaging, making the apply\(\) functionality incompatible with Puppet 6 agents. \([BOLT-840](https://tickets.puppetlabs.com/browse/BOLT-840)\)


## Fix race condition in Logging.logger \(0.23.0\)

Previously a race condition caused errors during transport initialization. This has been fixed. \([BOLT-828](https://tickets.puppetlabs.com/browse/BOLT-828)\)

## Local transport doesn't serialize arguments in environment variables to JSON \(0.22.0\)

The Local transport correctly serializes non-string parameters as JSON in environment variables. \([BOLT-807](https://tickets.puppetlabs.com/browse/BOLT-807)\)

## Bolt does not correctly report Puppet absent running 'apply' on newer Powershell \(0.22.0\)

Bolt correctly identifies when Puppet is absent while running the apply command over newer versions of Powershell. \([BOLT-812](https://tickets.puppetlabs.com/browse/BOLT-812)\)

## --no-host-key-check option does host key verification \(0.21.8\)

Previously, when host-key-check was set to false, lenient host key verification was performed. Now when host-key-check is false, no host key verification is performed. \([BOLT-805](https://tickets.puppetlabs.com/browse/BOLT-805)\)

## Handle poorly behaved providers \(0.21.8\)

On Windows, failing to remove the temporary modulepath no longer prevents the `apply` command from finishing successfully. It does however leave the directory around on the target. \([BOLT-772](https://tickets.puppetlabs.com/browse/BOLT-772)\)

## Race condition in transport logger initialization \(0.21.8\)

A race condition that resulted in errors saying "can't add a new key into hash during iteration" has been fixed. \([BOLT-685](https://tickets.puppetlabs.com/browse/BOLT-685)\)

## White space in Puppet Enterprise RBAC token files prevents validation \(0.21.6\)

Previously, when Bolt used a token file that contained white space, tokens failed with an HTTP error. \([BOLT-706](https://tickets.puppetlabs.com/browse/BOLT-706)\)

## Apply manifest block cannot use functions from boltlib from module that declares metadata \(0.21.6\)

You can apply a manifest block that includes functions from boltlib in a module that has metadata.json. Previously it only worked from within a module without metadata. \([BOLT-745](https://tickets.puppetlabs.com/browse/BOLT-745)\)

## Custom facts and features are not available for provider confine checks \(0.21.6\)

You can use custom facts and features in provider confine statements within a manifest block. \([BOLT-757](https://tickets.puppetlabs.com/browse/BOLT-757)\)

## apply\_prep throws unhelpful exception when failing to run tasks \(0.21.6\)

If `apply_prep` fails trying to run a task, it gives a useful error. \([BOLT-753](https://tickets.puppetlabs.com/browse/BOLT-753)\)

## \#\{owner\} resolves to nothing in a container on Docker for Mac \(0.21.6\)

The apply action did not work when run against some containers under Docker for Mac. This has been fixed. \([BOLT-735](https://tickets.puppetlabs.com/browse/BOLT-735)\)

## Output of ruby script over WinRM not consistent \(0.21.5\)

Scripts and tasks that output many lines quickly would sometimes appear out-of-order. This was especially problematic when outputting multiline structured data \(like JSON\). The issue has been fixed. \([BOLT-698](https://tickets.puppetlabs.com/browse/BOLT-698)\)

## Stack trace when 'nodes' in inventory group is not an array \(0.21.5\)

To avoid confusing error messages, the structure of the Bolt inventory file is validated more carefully. \([BOLT-629](https://tickets.puppetlabs.com/browse/BOLT-629)\)

## Slow performance when running command and script \(0.21.4\)

Updates to the Bolt analytics data collection slowed the performance for `command run` and `script run`. This has been fixed. \([BOLT-705](https://tickets.puppetlabs.com/browse/BOLT-705)\)

## --boltdir option set Boltdir rather than config file \(0.21.4\)

The `--boltdir` option works correctly to set the directory where default config, inventory, and modulepath are found. \([BOLT-699](https://tickets.puppetlabs.com/browse/BOLT-699)\)

## Bolt does not serialize complex types as JSON \(0.21.3\)

Previously, complex input in Bolt did not follow the environment variable input method outlined in the [Puppet Programming Language Specification](https://github.com/puppetlabs/puppet-specifications/tree/master/tasks#environment-variables). Namely, numerical parameters and structured objects did not use their JSON representations. This has been fixed. \([BOLT-677](https://tickets.puppetlabs.com/browse/BOLT-677)\)

## PowerShell-based tasks throw an error about a nonexistent parameter \(0.21.2\)

The PowerShell wrapper that prepares arguments effectively ignores any parameters that are specified in the metadata but not in the script. \([BOLT-630](https://tickets.puppetlabs.com/browse/BOLT-630)\)

## Unable to target 'localhost' on Windows \(0.21.1\)

Previously, running a PowerShell task on the target node `localhost` resulted in the error, "The local transport is not yet implemented on Windows." This has been fixed; the local transport is no longer the default when targeting localhost on Windows. \([BOLT-583](https://tickets.puppetlabs.com/browse/BOLT-583)\)

## Bolt sends invalid \_task key to orchestrator \(0.21.0\)

Bolt no longer sends invalid keys to Puppet orchestrator. \([BOLT-597](https://tickets.puppetlabs.com/browse/BOLT-597)\)

## upload/script/task doesn't work with `--run-as` command on AIX \(0.20.6\)

The command `--run-as` works on AIX. Non-portable management of file ownership has been fixed.\([BOLT-546](https://tickets.puppetlabs.com/browse/BOLT-546)\)

## Bolt fails when mktemp is not available \(0.20.6\)

Bolt no longer fails when creating a temporary directory on systems that don't include `mktemp`, such as AIX. \([BOLT-545](https://tickets.puppetlabs.com/browse/BOLT-545)\)

## PowerShell files do not appear to be powershell, but STDIN \(0.20.6\)

Previously, Bolt did not default to the `powershell` input type for PowerShell scripts run over WinRM. This has been fixed. \([BOLT-536](https://tickets.puppetlabs.com/browse/BOLT-536)\)

## Bolt hangs when no sudo password is provided \(0.20.6\)

Bolt no longer hangs when logging in via Bash and sudo requires a password but none is provided. \([BOLT-534](https://tickets.puppetlabs.com/browse/BOLT-534)\)

## Completion message for plans with no result \(0.20.3\)

The message "Plan completed successfully with no result" will once again be printed for plans with no result. Previously, "null" was printed for these plans. \([BOLT-532](https://tickets.puppetlabs.com/browse/BOLT-532)\)

## Concurrency limit enforced \(0.20.3\)

The global configuration option `concurrency`, which determines the number of threads to use when executing on remote nodes, is enforced. Previously, all jobs ran with unlimited concurrency. \([BOLT-520](https://tickets.puppetlabs.com/browse/BOLT-520)\)

## Facts task detects Ubuntu \(0.20.3\)

The facts task correctly detects the Ubuntu OS name and family when `lsb_release` is not present. \([BOLT-518](https://tickets.puppetlabs.com/browse/BOLT-518)\)

## Bolt gem repackaged with missing code \(0.20.2\)

Code required to run the commands `bolt task` and `bolt plan` has been added to the Bolt gem. This code was not included in the Bolt 0.20.0 release. \([BOLT-524](https://tickets.puppetlabs.com/browse/BOLT-524)\)

## Plans accept --query flag \(0.20.2\)

You can use the --query flag when you use the command `bolt plan run`. \([BOLT-486](https://tickets.puppetlabs.com/browse/BOLT-486)\)

## Correction to environment variables \(0.20.0\)

Environment variables are inherited with `sudo -E` if running a task that requires that arguments are passed as environment variables in its metadata. \([BOLT-505](https://tickets.puppetlabs.com/browse/BOLT-505)\)

## Canary plan fails when nodes fail \(0.20.0\)

The canary plan fails when an action fails on any target node. Previously it returned a resultset containing failures instead of failing with an error. \([BOLT-485](https://tickets.puppetlabs.com/browse/BOLT-485)\)

## Configure default transport from bolt.yaml \(0.20.0\)

In bolt.yaml, you can configure a default transport to use when none is specified in the URL. \([BOLT-484](https://tickets.puppetlabs.com/browse/BOLT-484)\)

-   **[Resolved issues \(0.19.x and earlier\)](bolt_resolved_issues-019.md)**  
Security and bug fixes in the Bolt 0.6 to 0.19 release series.

