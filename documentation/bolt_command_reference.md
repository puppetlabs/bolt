# Bolt command reference

These subcommands, actions, and options are available for Bolt.

## Global options

These options are available for all subcommands and actions.

| Option | Description|
|--------|------------|
|`-h`, `--help` | Display the help text.|
|`--version`|Display the Bolt version.|
|`--debug`|Display debug logging.|

## `apply`

Apply a Puppet manifest file.

**Usage**

`bolt apply <MANIFEST> <TARGETS>`

You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

**Options**

|Option|Description|Default|
|------|-----------|-------|
|`-n`, `--nodes NODES`|Alias for `--targets`.| |
|`-t`, `--targets TARGETS`|The target nodes to apply the manifest to.| |
|`-q`, `--query QUERY`|Query PuppetDB to determine the target nodes. Enter a comma-separated list of target URIs or group names, or read a target list from an input file `@FILE` or stdin `-`| |
|`--rerun FILTER`|Retry on nodes from the last run. `all` runs on all targets from the last run. `failure` runs on all targets that failed in the last run. `success` runs on all targets that succeeded in the last run.| |
|`--noop`|Execute a task that supports it in noop mode. | |
|`--description DESCRIPTION`|The description to use for the job. | |
|`-e`, `--execute CODE`|Puppet manifest code to apply to the targets.| |
|**Authentication**| | |
|`-u`, `--user USER`|User to authenticate as.| |
|`-p`, `--password [PASSWORD]`|Password to authenticate with. Omit the value to force a prompt for the password.| |
|`--private-key KEY`|Private SSH key to authenticate with.| |
|`--[no-]host-key-check`|Check host keys with SSH.| |
|`--[no-]ssl`|Use SSL with WinRM.| |
|`--[no-]ssl-verify`|Verify remote host SSL certificate with WinRM.| |
|**Escalation**| | |
|`--run-as USER`|User to run as using privilege escalation.| |
|`--sudo-password [PASSWORD]`|Password for privilege escalation. Omit the value to prompt for the password.| |
|**Run context**| | |
|`-c`, `--concurrency CONCURRENCY`|Maximum number of simultaneous connections.|100|
|`--compile-concurrency CONCURRENCY`|Maximum number of simultaneous manifest block compiles.|Number of cores|
|`-m`, `--modulepath FILEPATHS`|List of directories containing modules, separated by `:`. Directories are case-sensitive.| |
|`--boltdir FILEPATH`|Boltdir to load configuration settings from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|File to load configuration settings from.|`~/.puppetlabs/bolt/bolt.yaml`|
|`-i`, `--inventoryfile FILEPATH`|File to load inventory from.|`~/.puppetlabs/bolt/inventory.yaml`|
|`--[no-]save-rerun`|Whether to update the rerun file after this command.| |
|**Transport**| | |
|`--transport TRANSPORT`|The default transport for Bolt to use when connecting to remote nodes. `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote`| |
|`--connect-timeout TIMEOUT`|Connection timeout.|Varies|
|`--[no-]tty`|Request a pseudo TTY on nodes that support it.| |
|**Display**| | |
|`--format FORMAT`|Output format to use. `human`, `json`| |
|`--[no-]color`|Whether to show output in color.| |
|`-v`, `--[no-]verbose`|Display verbose logging.| |
|`--trace`|Display error trace stacks.| |

## `command run`

Run a command on remote targets.

**Usage**

`bolt command run <COMMAND> <TARGETS>`

Surround the command with single quotes if it contains spaces or special characters.

You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

|Option|Description|Default|
|------|-----------|-------|
|`--n`, `--nodes NODES`|Alias for `--targets`.| |
|`-t`, `--targets TARGETS`|Identifies the targets of command.| |
|`-q`, `--query QUERY`|Query PuppetDB to determine the targets. Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@FILE` or stdin `-`.| |
|`--rerun FILTER`|Retry on nodes from the last run. `all` runs on all targets from the last run. `failure` runs on all targets that failed in the last run. `success` runs on all targets that succeeded in the last run.| |
|`--description DESCRIPTION`|Description to use for the job.| |
|**Authentication**| | |
|`-u`, `--user USER`|User to authenticate as.| |
|`-p`, `--password [PASSWORD]`|Password to authenticate with. Omit the value to prompt for the password.| |
|`--private-key KEY`|Private SSH key to authenticate with.| |
|`--[no-]host-key-check`|Check host keys with SSH.| |
|`--[no-]ssl`|Use SSL with WinRM.| |
|`--[no-]ssl-verify`|Verify remote host SSL certificate with WinRM.| |
|**Escalation**| | |
|`--run-as USER`|User to run as using privilege escalation.| |
|`--sudo-password [PASSWORD]`|Password for privilege escalation. Omit the value to prompt for the password.| |
|**Run context**| | |
|`-c`, `--concurrency CONCURRENCY`|Maximum number of simultaneous connections.|100|
|`-m`, `--modulepath FILEPATHS`|List of directories containing modules, separated by `:`. Directories are case-sensitive.| |
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|
|`-i`, `--inventoryfile FILEPATH`|Specify where to load inventory from.|`~/.puppetlabs/bolt/inventory.yaml`|
|`--[no-]save-rerun`|Whether to update the rerun file after this command.| |
|**Transports**| | |
|`--transport TRANSPORT`|The default transport for Bolt to use when connecting to remote nodes. `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote`| |
|`--connect-timeout TIMEOUT`|Connection timeout.|Varies|
|`--[no-]tty`|Request a pseudo TTY on nodes that support it.| |
|**Display**| | |
|`--format FORMAT`|Output format to use. `human`, `json`| |
|`--[no-]color`|Whether to show output in color.| |
|`-v`, `--[no-]verbose`|Display verbose logging.| |
|`--trace`|Display error trace stacks.| |

## `file upload`

Upload a local file or directory.

**Usage**

`bolt file upload <SRC> <DEST> <TARGETS>`

You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

**Options**

|Option|Description|Default|
|------|-----------|-------|
|`-n`, `--nodes NODES`|Alias for `--targets`.| |
|`-t`, `--targets TARGETS`|Identifies the targets of command.| |
|`-q`, `--query QUERY`|Query PuppetDB to determine the targets. Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@FILE` or stdin `-`.| |
|`--rerun FILTER`|Retry on nodes from the last run. `all` runs on all targets from the last run. `failure` runs on all targets that failed in the last run. `success` runs on all targets that succeeded in the last run.| |
|`--description DESCRIPTION`|Description to use for the job.| |
|**Authentication**| | |
|`-u`, `--user USER`|User to authenticate as.| |
|`-p`, `--password [PASSWORD]`|Password to authenticate with. Omit the value to prompt for the password.| |
|`--private-key KEY`|Private SSH key to authenticate with.| |
|`--[no-]host-key-check`|Check host keys with SSH.| |
|`--[no-]ssl`|Use SSL with WinRM.| |
|`--[no-]ssl-verify`|Verify remote host SSL certificate with WinRM.| |
|**Escalation**| | |
|`--run-as USER`|User to run as using privilege escalation.| |
|`--sudo-password [PASSWORD]`|Password for privilege escalation. Omit the value to prompt for the password.| |
|**Run Context**| | |
|`-c`, `--concurrency CONCURRENCY`|Maximum number of simultaneous connections.|100|
|`-m`, `--modulepath FILEPATHS`|List of directories containing modules, separated by `:`. Directories are case-sensitive.| |
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|
|`-i`, `--inventoryfile FILEPATH`|Specify where to load inventory from.|`~/.puppetlabs/bolt/inventory.yaml`|
|`--[no-]save-rerun`|Whether to update the rerun file after this command.| |
|**Transports**| | |
|`--transport TRANSPORT`|The default transport for Bolt to use when connecting to remote nodes. `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote`| |
|`--connect-timeout TIMEOUT`|Connection timeout.|Varies|
|`--[no-]tty`|Request a pseudo TTY on nodes that support it.| |
|`--tmpdir DIR`|The directory to upload and execute temporary files on the target.| |
|**Display**| | |
|`--format FORMAT`|Output format to use. `human`, `json`| |
|`--[no-]color`|Whether to show output in color.| |
|`-v`, `--[no-]verbose`|Display verbose logging.| |
|`--trace`|Display error trace stacks.| |

## `group show`

Show the list of groups in the inventory

**Usage**

`bolt group show`

**Options**

|Option|Description|Default|
|------|-----------|-------|
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|
|`-i`, `--inventoryfile FILEPATH`|Specify where to load inventory from.|`~/.puppetlabs/bolt/inventory.yaml`|
|**Display**| | |
|`--format FORMAT`|Output format to use. `human`, `json`| |

## `inventory show`

Show the list of targets an action would run on.

**Usage**

`bolt inventory show <TARGETS>`

You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

**Options**

|Option|Description|Default|
|------|-----------|-------|
|`-n`, `--nodes NODES`|Alias for `--targets`.| |
|`-t`, `--targets TARGETS`|Identifies the targets of command.| |
|`-q`, `--query QUERY`|Query PuppetDB to determine the targets. Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@<file>` or stdin `-`.| |
|`--rerun FILTER`|Retry on nodes from the last run. `all` runs on all targets from the last run. `failure` runs on all targets that failed in the last run. `success` runs on all targets that succeeded in the last run.| |
|**Run Context**| | |
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|
|`-i`, `--inventoryfile FILEPATH`|Specify where to load inventory from.|`~/.puppetlabs/bolt/inventory.yaml`|
|**Display**| | |
|`--format FORMAT`|Output format to use. `human`, `json`| |

## `plan convert`

Convert a YAML plan to a Puppet plan.

**Usage**

`bolt plan convert <PLAN>`

**Options**

|Option|Description|Default|
|------|-----------|-------|
|**Run Context**| | |
|`-m`, `--modulepath FILEPATHS`|List of directories containing modules, separated by `:`. Directories are case-sensitive.| |
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|

## `plan run`

Run a Puppet task plan on remote targets.

**Usage**

bolt plan run <PLAN> <TARGETS>

Plan parameters are of the form `parameter=value`.

You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

**Options**

|Option|Description|Default|
|------|-----------|-------|
|`-n`, `--nodes NODES`|Alias for `--targets`.| |
|`-t`, `--targets TARGETS`|Identifies the targets of command.| |
|`-q`, `--query QUERY`|Query PuppetDB to determine the targets. Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@<file>`or stdin `-`.| |
|`--rerun FILTER`|Retry on nodes from the last run. `all` runs on all targets from the last run. `failure` runs on all targets that failed in the last run. `success` runs on all targets that succeeded in the last run.| |
|`--description DESCRIPTION`|Description to use for the job.| |
|`--params PARAMETERS`|Parameters to a task or plan as json, a json file `@<file>`, or on stdin `-`.| |
|**Authentication**| | |
|`-u`, `--user USER`|User to authenticate as.| |
|`-p`, `--password [PASSWORD]`|Password to authenticate with. Omit the value to prompt for the password.| |
|`--private-key KEY`|Private SSH key to authenticate with.| |
|`--[no-]host-key-check`|Check host keys with SSH.| |
|`--[no-]ssl`|Use SSL with WinRM.| |
|`--[no-]ssl-verify`|Verify remote host SSL certificate with WinRM.| |
|**Escalation**| | |
|`--run-as USER`|User to run as using privilege escalation.| |
|`--sudo-password [PASSWORD]`|Password for privilege escalation. Omit the value to prompt for the password.| |
|**Run Context**| | |
|`-c`, `--concurrency CONCURRENCY`|Maximum number of simultaneous connections.|100|
|`--compile-concurrency CONCURRENCY`|Maximum number of simultaneous manifest block compiles.|Number of cores|
|`-m`, `--modulepath FILEPATHS`|List of directories containing modules, separated by `:`. Directories are case-sensitive.| |
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|
|`-i`, `--inventoryfile FILEPATH`|Specify where to load inventory from.|`~/.puppetlabs/bolt/inventory.yaml`|
|`--[no-]save-rerun`|Whether to update the rerun file after this command.| |
|**Transports**| | |
|`--transport TRANSPORT`|Specify a default transport. `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote`| |
|`--connect-timeout TIMEOUT`|Connection timeout.|Varies|
|`--[no-]tty`|Request a pseudo TTY on nodes that support it.| |
|`--tmpdir DIR`|The directory to upload and execute temporary files on the target.| |
|**Display**| | |
|`--format FORMAT`|Output format to use. `human`, `json`| |
|`--[no-]color`|Whether to show output in color.| |
|`-v`, `--[no-]verbose`|Display verbose logging.| |
|`--trace`|Display error trace stacks.| |

## `plan show`

Show a list of available plans or details for a specific plan.

**Usage**

`bolt plan show [PLAN]`

Specify an available plan to show documentation for the plan.

**Options**

|Option|Description|Default|
|------|-----------|-------|
|**Run Context**| | |
|`-m`, `--modulepath FILEPATHS`|List of directories containing modules, separated by `:`. Directories are case-sensitive.| |
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|

## `puppetfile install`

Install modules from a Puppetfile into a Boltdir.

**Usage**

`bolt puppetfile install`

A file named `Puppetfile` must exist in the Boltdir.

Options

|Option|Description|Default|
|------|-----------|-------|
|**Run Context**| | |
|`-m`, `--modulepath FILEPATHS`|List of directories containing modules, separated by `:`. Directories are case-sensitive.| |
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|

## `puppetfile show-modules`

List modules available to Bolt.

**Usage**

`bolt puppetfile show-modules`

**Options**

## `puppetfile generate-types`

Generate type references to register in Plans

### Usage

`bolt puppetfile generate-types`

|Option|Description|Default|
|------|-----------|-------|
|**Run Context**| | |
|`-m`, `--modulepath FILEPATHS`|List of directories containing modules, separated by `:`. Directories are case-sensitive.| |
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|

## `script run`

Run a local script on remote targets.

**Usage**

`bolt script run <SCRIPT> <TARGETS> [ARGS]`

**Options**

|Option|Description|Default|
|------|-----------|-------|
|`-n`, `--nodes NODES`|Alias for `--targets`.| |
|`-t`, `--targets TARGETS`|Identifies the targets of command.| |
|`-q`, `--query QUERY`|Query PuppetDB to determine the targets. Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@<file>` or stdin `-`.| |
|`--rerun FILTER`|Retry on nodes from the last run. `all` runs on all targets from the last run. `failure` runs on all targets that failed in the last run. `success` runs on all targets that succeeded in the last run.| |
|`--description DESCRIPTION`|Description to use for the job.| |
|**Authentication**| | |
|`-u`, `--user USER`|User to authenticate as.| |
|`-p`, `--password [PASSWORD]`|Password to authenticate with. Omit the value to prompt for the password.| |
|`--private-key KEY`|Private SSH key to authenticate with.| |
|`--[no-]host-key-check`|Check host keys with SSH.| |
|`--[no-]ssl`|Use SSL with WinRM.| |
|`--[no-]ssl-verify`|Verify remote host SSL certificate with WinRM.| |
|**Escalation**| | |
|`--run-as USER`|User to run as using privilege escalation.| |
|`--sudo-password [PASSWORD]`|Password for privilege escalation. Omit the value to prompt for the password.| |
|**Run Context**| | |
|`-c`, `--concurrency CONCURRENCY`|Maximum number of simultaneous connections.|100|
|`-m`, `--modulepath FILEPATHS`|List of directories containing modules, separated by `:`. Directories are case-sensitive.| |
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|
|`-i`, `--inventoryfile FILEPATH`|Specify where to load inventory from.|`~/.puppetlabs/bolt/inventory.yaml`|
|`--[no-]save-rerun`|Whether to update the rerun file after this command.| |
|**Transports**| | |
|`--transport TRANSPORT`|Specify a default transport. `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote`| |
|`--connect-timeout TIMEOUT`|Connection timeout.|Varies|
|`--[no-]tty`|Request a pseudo TTY on nodes that support it.| |
|`--tmpdir DIR`|The directory to upload and execute temporary files on the target.| |
|**Display**| | |
|`--format FORMAT`|Output format to use. `human`, `json`| |
|`--[no-]color`|Whether to show output in color.| |
|`-v`, `--[no-]verbose`|Display verbose logging.| |
|`--trace`|Display error trace stacks.| |

## `secret createkeys`

Create new encryption keys.

**Usage**

`bolt secret createkeys`

Bolt saves keys to the `keys` directory in the Boltdir.

**Options**

|Option|Description|Default|
|------|-----------|-------|
|**Run Context**| | |
|`--boltdir FILEPATH`|Specify what Boltdir to save keys to.|Autodiscovered from current working directory.|

## `secret decrypt`

Decrypt a value.

**Usage**

`bolt secret decrypt <CIPHERTEXT>`

**Options**

|Option|Description|Default|
|------|-----------|-------|
|**Run Context**| | |
|`--boltdir FILEPATH`|Specify what Boltdir to load keys from.|Autodiscovered from current working directory.|

## `secret encrypt`

Encrypt a value.

**Usage**

`bolt secret encrypt <PLAINTEXT>`

**Options**

|Option|Description|Default|
|------|-----------|-------|
|**Run Context**| | |
|`--boltdir FILEPATH`|Specify what Boltdir to load keys from.|Autodiscovered from current working directory.|

## `task run`

Run a Puppet task on remote targets.

**Usage**

`bolt task run <TASK> <TARGETS>`

Task parameters are of the form `parameter=value`.

You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

**Options**

|Option|Description|Default|
|------|-----------|-------|
|`-n`, `--nodes NODES`|Alias for `--targets`.| |
|`-t`, `--targets TARGETS`|Identifies the targets of command.| |
|`-q`, `--query QUERY`|Query PuppetDB to determine the targets. Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@<file>`or stdin `-`.| |
|`--rerun FILTER`|Retry on nodes from the last run. `all` runs on all targets from the last run. `failure` runs on all targets that failed in the last run. `success` runs on all targets that succeeded in the last run.| |
|`--description DESCRIPTION`|Description to use for the job.| |
|`--params PARAMETERS`|Parameters to a task or plan as json, a json file `@<FILE>`, or on stdin `-`.| |
|**Authentication**| | |
|`-u`, `--user USER`|User to authenticate as.| |
|`-p`, `--password [PASSWORD]`|Password to authenticate with. Omit the value to prompt for the password.| |
|`--private-key KEY`|Private SSH key to authenticate with.| |
|`--[no-]host-key-check`|Check host keys with SSH.| |
|`--[no-]ssl`|Use SSL with WinRM.| |
|`--[no-]ssl-verify`|Verify remote host SSL certificate with WinRM.| |
|**Escalation**| | |
|`--run-as USER`|User to run as using privilege escalation.| |
|`--sudo-password [PASSWORD]`|Password for privilege escalation. Omit the value to prompt for the password.| |
|**Run Context**| | |
|`-c`, `--concurrency CONCURRENCY`|Maximum number of simultaneous connections.|100|
|`--compile-concurrency CONCURRENCY`|Maximum number of simultaneous manifest block compiles.|Number of cores|
|`-m`, `--modulepath FILEPATHS`|List of directories containing modules, separated by `:`. Directories are case-sensitive.| |
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|
|`-i`, `--inventoryfile FILEPATH`|Specify where to load inventory from.|`~/.puppetlabs/bolt/inventory.yaml`|
|`--[no-]save-rerun`|Whether to update the rerun file after this command.| |
|**Transports**| | |
|`--transport TRANSPORT`|Specify a default transport. `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote`| |
|`--connect-timeout TIMEOUT`|Connection timeout.|Varies|
|`--[no-]tty`|Request a pseudo TTY on nodes that support it.| |
|`--tmpdir DIR`|The directory to upload and execute temporary files on the target.| |
|**Display**| | |
|`--format FORMAT`|Output format to use. `human`, `json`| |
|`--[no-]color`|Whether to show output in color.| |
|`-v`, `--[no-]verbose`|Display verbose logging.| |
|`--trace`|Display error trace stacks.| |

## `task show`

Show a list of available tasks or details for a specific task.

**Usage**

`bolt task show [TASK]`

Specify an available task to show documentation for the task.

**Options**

|Option|Description|Default|
|------|-----------|-------|
|**Run Context**| | |
|`-m`, `--modulepath FILEPATHS`|List of directories containing modules, separated by `:`. Directories are case-sensitive.| |
|`--boltdir FILEPATH`|Specify what Boltdir to load config from.|Autodiscovered from current working directory.|
|`--configfile FILEPATH`|Specify where to load config from.|`~/.puppetlabs/bolt/bolt.yaml`|

**Secret options**

|Option|Description|
|------|-----------|
|`--plugin`|Which plugin to use.|
