---
author: Kate Lopresti <kate.lopresti@puppet.com\>
---

# Resolved issues \(0.19.x and earlier\)

Security and bug fixes in the Bolt 0.6 to 0.19 release series.

## Puppet log format matches Bolt \(0.19.1\)

Log functions in Puppet use the same format, level, and destinations as other Bolt logs. \([BOLT-455](https://tickets.puppetlabs.com/browse/BOLT-455)\)

## Specifying parameter file on PowerShell \(0.18.2\)

For Windows PowerShell, you can pass a JSON parameter file by adding single quotation marks where you define the file.

```
--params '@params.json'
```

\([BOLT-102](https://tickets.puppetlabs.com/browse/BOLT-102)\)

## Log output available during plan runs \(0.18.2\)

Complete log output is available when you make `run_*` calls. \([BOLT-434](https://tickets.puppetlabs.com/browse/BOLT-434)\)

## Correction to target objects that store variables \(0.18.1\)

You can access the `vars`property for a target object that is not listed in an inventory file. \([BOLT-435](https://tickets.puppetlabs.com/browse/BOLT-433)\)

## Correction to bolt-inventory-pdb \(0.18.1\)

The command `bolt-inventory-pdb` runs as expected. Changes from a previous release caused this command to fail with the message, `Error: uninitialized constant Bolt::PuppetDB::Client`. \([BOLT-433](https://tickets.puppetlabs.com/browse/BOLT-433)\)

## Correction to command line support for JSON \(0.18.1\)

Parameter values are correctly parsed as JSON only when they match the data type. Previously, for plans, string values were also parsed as JSON. \([BOLT-432](https://tickets.puppetlabs.com/browse/BOLT-432)\)

## TargetSpec parameter recognized \(0.18.1\)

The `TargetSpec` parameter is a recognized resource type when you run the command `bolt plan show <plan>`. Previously this command failed when run for plans that used the `TargetSpec` parameter. \([BOLT-407](https://tickets.puppetlabs.com/browse/BOLT-407)\)

## Correction to local transport protocol \(0.18.0\)

Previously, `localhost` was added as an inventory target for local transport. As a result it was added to the `all` group even when it was not mentioned in the inventory. The `all` group has been updated to include only targets from the inventory; `localhost` is no longer added automatically. \([BOLT-388](https://tickets.puppetlabs.com/browse/BOLT-388)\)

## Target object uses string keys \(0.17.2\)

The `options` property of the `Target` object uses string keys. You can use it in the Plan language. \([BOLT-366](https://tickets.puppetlabs.com/browse/BOLT-366)\)

## Correction to transport protocols \(0.17.0\)

Previously, when you configured different transport protocols for nodes in an inventory file, each protocol was applied to each node when running commands. This resulted in failed connection errors. Now only the transport protocol configured for a particular node is used on that node. \([BOLT-363](https://tickets.puppetlabs.com/browse/BOLT-363)\)

## PCP transport configuration options are recognized \(0.17.0\)

The PCP transport options `token-file` or `service-url` that you specify in the configuration file \(`bolt.yaml)` are recognized in Bolt. Previously, only the default `token-file` location was used and the `service-url` value was ignored.

## Improved error handling for bolt-inventory-pdb \(0.17.0\)

`bolt-inventory-pdb` now provides an accurate error message when called without additional arguments. Errors no longer occur when a puppetdb.conf file is not present \(you can use command-line flags in place of a config file\) or when `server-urls` is a single string instead of an array. \([BOLT-357](https://tickets.puppetlabs.com/browse/BOLT-357)\)

## Improvements to orchestrator configuration file settings \(0.16.4\)

You can now specify orchestrator config in inventory files and set up different targets to use different orchestrators. \([BOLT-346](https://tickets.puppetlabs.com/browse/BOLT-346)\)

## Connection error appears for bolt command run \(0.16.3\)

When a connection error occurs while you run `bolt command run`, a `Failed to connect` error now appears. \([BOLT-344](https://tickets.puppetlabs.com/browse/BOLT-344)\)

## Parameter variables properly escaped \(0.16.3\)

Previously task parameters passed as environment variables with ssh were not escaped. This caused some tasks to fail without a clear explanation. \([BOLT-340](https://tickets.puppetlabs.com/browse/BOLT-340)\)

## Bolt runs with sudo password \(0.16.2\)

Bolt correctly responds when you provide the sudo password in the run command. Previously, if you provided the sudo password and it caused the sudo lecture to appear, the run would fail. \([BOLT-326](https://tickets.puppetlabs.com/browse/BOLT-326)\)

## Improved error messaging for unfound tasks \(0.16.2\)

When you enter a task name that cannot be found, an error message directs you to use command `bolt task show` to see a list of available tasks. \([BOLT-198](https://tickets.puppetlabs.com/browse/BOLT-198)\)

## Installation failures with recent Ruby-FFI extensions \(0.16.1\)

In some cases newer releases of FFI Extensions for Ruby were causing installation issues. As a result, Bolt now uses Ruby-FFI version 1.9.18. \( [BOLT-329](https://tickets.puppet.com/browse/BOLT-329)\)

## Unable to connect over WinRM HTTP with `bolt task` \(0.16.0\)

In some cases SSL initialization was slow on Windows after loading Puppet. This caused connection timeouts when you used `transport winrm`. This fix initializes SSL first in order to speed up initialization and prevent timeouts. \([BOLT-303](https://tickets.puppet.com/browse/BOLT-303)\)

## Empty parameters displayed as type `Data` \(0.16.0\)

Empty parameters have been updated to display as type `Any`.

 [\[BOLT-291\]](https://tickets.puppet.com/browse/BOLT-291) 

## SSH-agent threw an error on successful connection \(0.16.0\)

If `ssh-agent` is not running, Bolt no longer sends an error when trying to connect to nodes using SSH, even if the connection succeeds using password-based authentication. \([BOLT-81](https://tickets.puppet.com/browse/BOLT-81)\)

## SSL default made WinRM harder to use \(0.15.0\)

This fix improves logging for WinRM connection failures. \([BOLT-277](https://tickets.puppetlabs.com/browse/BOLT-277)\)

## Bolt didn't parse errors well \(0.14.0\)

This fix simplifies some errors reported from running tasks and plans. It also changes makes these improvements:

-   Prints human-formatted errors in running a subcommand to `stdout`.

-   Colors them red.

-   Stops reprinting JSON-formatted output errors on `stderr`.


Errors parsing Bolt configuration will continue to be output on `stderr`. \([BOLT-285](https://tickets.puppetlabs.com/browse/BOLT-285)\)

## Bolt wrote parameters to disk \(0.13.0\)

Writing parameters to disk is undesirable for sensitive inputs. This is changed now, so that Bolt only writes parameters to disk when specifying `--run-as`. \([BOLT-233](https://tickets.puppetlabs.com/browse/BOLT-233)\)

## `ExecutionResult` data type didn't load automatically \(0.13.0\)

This change fixes an issue where none of the `ExecutionResult` functions were loaded unless the data type was explicitly loaded. For example, `run_task(...).ok` would not work. \([BOLT-293](https://tickets.puppetlabs.com/browse/BOLT-293)\)

## ExecutionResult.to\_s caused stack trace \(0.13.0\)

This change fixes an issue where calling `to_s` on an `ExecutionResult` resulted in a stack depth exceeded error. For example, `"${run_task(...)}"` would fail. \([BOLT-294](https://tickets.puppetlabs.com/browse/BOLT-294)\)

## `bolt task show` displayed verbose parameter type \(0.13.0\)

`bolt task show` displayed a more verbose parameter type than was described. Type descriptions will no longer include `default` for unset arguments.

 [BOLT-284](https://tickets.puppetlabs.com/browse/BOLT-284) 

## The `run_task` function didn't verify that parameters were `Data` \(0.13.0\)

Task metadata with parameters other than `Data` are now allowed. The values of the parameters are instead checking in the `run_task` function to verify `Data`. \([BOLT-283](https://tickets.puppetlabs.com/browse/BOLT-283)\)

## Bolt didn't produce a useful error when the orchestrator skipped a task \(0.12.0\)

Bolt didn't handle skipped results from the orchestrator. This is fixed, and now these errors have a type, `puppetlabs.tasks/skipped-node`. \([BOLT-262](https://tickets.puppetlabs.com/browse/BOLT-262)\)

## Breaking change: Parameters in task metadata collided with metadata keys \(0.11.0\)

Bolt parameter names were ignored if they conflicted with top-level metadata keys, like parameters, input methods, and so on. This is fixed, but might be a breaking change.

Previously, tasks were types in Puppet and the `run task` function could be called with a reference to the type itself, or to an instance of the type. With this change, that is no longer the case. Now, tasks must be referred to by their lower case task name. Therefore:

-   `run_task(My_app::Deploy()` should be `run_task(my_app::deploy`,

-   Or `run_task(My_app::Deploy` should be `run_task('my_app::deploy'` 


\([PUP-8199](https://tickets.puppetlabs.com/browse/PUP-8199)\)

## Does supports the `powershell` input method \(0.10.0\)

Bolt does now supports the task input method `powershell`. [\[BOLT-156\]](https://tickets.puppet.com/browse/BOLT-156).

## WinRM connector didn't always propagate exit status properly in failure scenarios \(0.8.0\)

When executing against WinRM nodes and a script or task operation failed due to exiting the script with a non-0 exit code, a terminating PowerShell error, or a PowerShell parser failure, Bolt potentially incorrectly reported the result of the operation as a success. \[[BOLT-206](https://tickets.puppetlabs.com/browse/BOLT-206)\]

## Fix to prevent WinRM stream reading deadlock \(0.8.0\)

Bolt might have deadlocked when executing a script or task on a Windows host, and that host wrote more than 4k to `stderr`. \[[BOLT-200](https://tickets.puppetlabs.com/browse/BOLT-200)\]

## Error messages improved \(0.7.0\)

This release makes several vague or confusing error messages more helpful. \[[BOLT-187](https://tickets.puppet.com/browse/BOLT-187), [BOLT-189](https://tickets.puppet.com/browse/BOLT-189), [BOLT-197](https://tickets.puppet.com/browse/BOLT-197)\]

## Bolt is incompatible with `net-ssh` prior to 4.2 \(0.6.1\)

This release updates Bolt requirements to `net-ssh` version 4.2 or greater. If you have an earlier version of `net-ssh` installed, run `gem install bolt` or `gem update bolt` to automatically update the `net-ssh` dependency. [\[BOLT-192\]](https://tickets.puppet.com/browse/BOLT-192)

## Gem install failed on Ruby 2.0 \(0.6.1\)

Bolt gem install failed on Ruby 2.0 due to a transitive dependency on`public_suffix` 3.0, which requires Ruby 2.1 or greater. [\[BOLT-193\]](https://tickets.puppet.com/browse/BOLT-193)

## Bolt had issues with sudo passwords \(0.9.0\)

Bolt hung when you attempt to sudo with the wrong password or if you didn't provide a password when it was expected. These issues are fixed now.

BOLT-227 and BOLT-226

## Bolt defaults to secure verification with net-ssh \(0.6.0\)

Bolt failed to install on Ruby 2.0 due to a transitive dependency on `public_suffix` 3.0, which requires Ruby 2.1 or greater.

## Tasks with parameters matching Ruby keywords caused plan failure \(0.6.0\)

If a plan included a task that had parameters, attributes, or functions that had names that were the same as Ruby keywords, the plan run failed.

For example a task could not have a parameter named 'ensure' because of this problem. This is now fixed. [\[BOLT-8046\]](https://tickets.puppet.com/browse/BOLT-8046)

## Error message was unclear when connection to a node failed \(0.6.0\)

Now if Bolt fails to connect to a node over SSH or WinRM due to incorrect authentication and networking issues, the error is more helpful. [\[BOLT-141\]](https://tickets.puppet.com/browse/BOLT-141)

## Could not bundle install Bolt on Windows \(0.6.0\)

Bolt can now be installed with Bundle install from a Gemfile on Windows but for those is now possible to bundle install on Windows for development workflows. [\[BOLT-149\]](https://tickets.puppet.com/browse/BOLT-149)

## Passwords with special characters were not properly decoded \(0.6.0\)

If you tried to specify passwords with special characters in an SSH or WinRM URI, authentication failed. You can now specify such passwords in a node URI, such as `--nodes winrm://<user>:<password>@<hostname>`

## Error object can now accept a hash \(0.6.0\)

Previously, the Error object in plans could not be initialized from a hash with arguments. You could pass an error message only as a string. [\[BOLT-8056\]](https://tickets.puppet.com/browse/BOLT-8056)

