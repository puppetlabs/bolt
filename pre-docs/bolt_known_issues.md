# Known issues

Known issues for the Bolt 0.x release series.

## Task module removed from Bolt gem

Starting with Bolt 0.20.0, gems no longer include extra task modules. These modules are available in puppet-bolt packages. \[[BOLT-531](https://tickets.puppetlabs.com/browse/BOLT-311)\]

## Error from `run_task` plan causes uncaught exception \(0.15.0\)

Details of some exceptions generated within plans are lost when using Ruby 2.0. \[[BOLT-311](https://tickets.puppetlabs.com/browse/BOLT-311)\]

## Bolt does not load tasks from subdirectories

Bolt cannot find and load tasks located in module subdirectories. For example, Bolt could run a task located in `./tasks/mytask.sh` \(or `module::mytask`\), but not one located in `./tasks/examples/mytask.sh` \(or `module::examples::mytask`\) . [\[BOLT-190\]](https://tickets.puppet.com/browse/BOLT-190)

## Bolt does not support literal IPv6 addresses

Bolt supports IPv6 addresses when they [enclosed in square brackets](bolt_options.md#). [\[BOLT-120\]](https://tickets.puppet.com/browse/BOLT-120)

## Running Bolt from source sometimes causes errors on Linux

When running Bolt from source on some Linux distros, you may get the error "LoadError: cannot load such file -- io/console". [\[BOLT-80\]](https://tickets.puppet.com/browse/BOLT-80)

## Nodes are a String data type

The data type used in plans for a list of nodes is currently a generic String data type. Additionally, there is no built in functionality to split up a comma-separated list of nodes. [\[PUP-8020\]](https://tickets.puppet.com/browse/PUP-8020)

## String segments in commands must be triple-quoted in PowerShell

When running Bolt in PowerShell with commands to be run on \*nix nodes, string segments that can be interpreted by PowerShell need to be triple quoted.[\[BOLT-159\]](https://tickets.puppet.com/browse/BOLT-159)

**Parent topic:** [Bolt release notes](bolt_release_notes.md)

