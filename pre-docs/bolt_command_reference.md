# Bolt command reference

Review the subcommands, actions, and options that are available for Bolt.

- [apply](#apply)
- [command run](#command-run)
- [file upload](#file-upload)
- [inventory show](#inventory-show)
- [plan convert](#plan-convert)
- [plan run](#plan-run)
- [plan show](#plan-show)
- [puppetfile install](#puppetfile-install)
- [puppetfile show-modules](#puppetfile-show-modules)
- [script run](#script-run)
- [secret createkeys](#secret-createkeys)
- [secret decrypt](#secret-decrypt)
- [secret encrypt](#secret-encrypt)
- [task run](#task-run)
- [task show](#task-show)


## Global options

These options are available for all subcommands and actions:

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Display the help text. |
| `--version` | Display the version of Bolt. |
| `--debug` | Display debug logging. |


## `apply`

Apply a Puppet manifest file.

### Usage

`bolt apply <MANIFEST> <TARGETS>`

- You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-n`, `--nodes NODES` | Alias for `--targets`. |
| `-t`, `--targets TARGETS` | Identifies the targets of command. |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets. <br> Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@<file>` or stdin `-`. |
| `--rerun FILTER` | Retry on nodes from the last run. <br> `all` runs on all targets from the last run. <br> `failure` runs on all targets that failed in the last run. <br> `success` runs on all targets that succeeded in the last run. |
| `--noop` | Execute a task that supports it in noop mode. |
| `--description DESCRIPTION` | Description to use for the job. |
| `-e`, `--execute CODE` | Puppet manifest code to apply to the targets. |
| **Authentication** |
| `-u`, `--user USER` | User to authenticate as. |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. <br> Omit the value to prompt for the password. |
| `--private-key KEY` | Private SSH key to authenticate with. |
| `--[no-]host-key-check` | Check host keys with SSH. |
| `--[no-]ssl` | Use SSL with WinRM. |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM. |
| **Escalation** |
| `--run-as USER` | User to run as using privilege escalation. |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. <br> Omit the value to prompt for the password. |
| **Run Context** |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections. | 100 |
| `--compile-concurrency CONCURRENCY` | Maximum number of simultaneous manifest block compiles. | Number of cores |
| `-m`, `--modulepath FILEPATHS` | List of directories containing modules, separated by `:`. <br> Directories are case-sensitive. |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from. | `~/.puppetlabs/bolt/inventory.yaml` |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| **Transports** |
| `--transport TRANSPORT` | Specify a default transport. <br> `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote` |
| `--connect-timeout TIMEOUT` | Connection timeout. | Varies |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it. |
| **Display** |
| `--format FORMAT` | Output format to use. <br> `human`, `json` |
| `--[no-]color` | Whether to show output in color. |
| `-v`, `--[no-]verbose` | Display verbose logging. |
| `--trace` | Display error trace stacks. |


## `command run`

Run a command on remote targets.

### Usage

`bolt command run <COMMAND> <TARGETS>`

- Single quote the command if it contains spaces or special characters.
- You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-n`, `--nodes NODES` | Alias for `--targets`. |
| `-t`, `--targets TARGETS` | Identifies the targets of command. |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets. <br> Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@<file>` or stdin `-`. |
| `--rerun FILTER` | Retry on nodes from the last run. <br> `all` runs on all targets from the last run. <br> `failure` runs on all targets that failed in the last run. <br> `success` runs on all targets that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job. |
| **Authentication** |
| `-u`, `--user USER` | User to authenticate as. |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. <br> Omit the value to prompt for the password. |
| `--private-key KEY` | Private SSH key to authenticate with. |
| `--[no-]host-key-check` | Check host keys with SSH. |
| `--[no-]ssl` | Use SSL with WinRM. |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM. |
| **Escalation** |
| `--run-as USER` | User to run as using privilege escalation. |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. <br> Omit the value to prompt for the password. |
| **Run Context** |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections. | 100 |
| `-m`, `--modulepath FILEPATHS` | List of directories containing modules, separated by `:`. <br> Directories are case-sensitive. |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from. | `~/.puppetlabs/bolt/inventory.yaml` |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| **Transports** |
| `--transport TRANSPORT` | Specify a default transport. <br> `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote` |
| `--connect-timeout TIMEOUT` | Connection timeout. | Varies |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it. |
| **Display** |
| `--format FORMAT` | Output format to use. <br> `human`, `json` |
| `--[no-]color` | Whether to show output in color. |
| `-v`, `--[no-]verbose` | Display verbose logging. |
| `--trace` | Display error trace stacks. |


## `file upload`

Upload a local file or directory.

### Usage

`bolt file upload <SRC> <DEST> <TARGETS>`

- You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-n`, `--nodes NODES` | Alias for `--targets`. |
| `-t`, `--targets TARGETS` | Identifies the targets of command. |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets. <br> Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@<file>` or stdin `-`. |
| `--rerun FILTER` | Retry on nodes from the last run. <br> `all` runs on all targets from the last run. <br> `failure` runs on all targets that failed in the last run. <br> `success` runs on all targets that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job. |
| **Authentication** |
| `-u`, `--user USER` | User to authenticate as. |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. <br> Omit the value to prompt for the password. |
| `--private-key KEY` | Private SSH key to authenticate with. |
| `--[no-]host-key-check` | Check host keys with SSH. |
| `--[no-]ssl` | Use SSL with WinRM. |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM. |
| **Escalation** |
| `--run-as USER` | User to run as using privilege escalation. |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. <br> Omit the value to prompt for the password. |
| **Run Context** |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections. | 100 |
| `-m`, `--modulepath FILEPATHS` | List of directories containing modules, separated by `:`. <br> Directories are case-sensitive. |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from. | `~/.puppetlabs/bolt/inventory.yaml` |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| **Transports** |
| `--transport TRANSPORT` | Specify a default transport. <br> `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote` |
| `--connect-timeout TIMEOUT` | Connection timeout. | Varies |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it. |
| `--tmpdir DIR` | The directory to upload and execute temporary files on the target. |
| **Display** |
| `--format FORMAT` | Output format to use. <br> `human`, `json` |
| `--[no-]color` | Whether to show output in color. |
| `-v`, `--[no-]verbose` | Display verbose logging. |
| `--trace` | Display error trace stacks. |


## `inventory show`

Show the list of targets an action would run on.

### Usage

`bolt inventory show <TARGETS>`

- You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-n`, `--nodes NODES` | Alias for `--targets`. |
| `-t`, `--targets TARGETS` | Identifies the targets of command. |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets. <br> Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@<file>` or stdin `-`. |
| `--rerun FILTER` | Retry on nodes from the last run. <br> `all` runs on all targets from the last run. <br> `failure` runs on all targets that failed in the last run. <br> `success` runs on all targets that succeeded in the last run. |
| **Run Context** |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from. | `~/.puppetlabs/bolt/inventory.yaml` |
| **Display** |
| `--format FORMAT` | Output format to use. <br> `human`, `json` |


## `plan convert`

Convert a YAML plan to a Puppet plan.

### Usage

`bolt plan convert <PLAN>`

### Options

| Option | Description | Default |
|--------|-------------|---------|
| **Run Context** |
| `-m`, `--modulepath FILEPATHS` | List of directories containing modules, separated by `:`. <br> Directories are case-sensitive. |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |


## `plan run`

Run a Puppet task plan on remote targets.

### Usage

`bolt plan run <PLAN> <TARGETS>`

- Plan parameters are of the form `parameter=value`.
- You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-n`, `--nodes NODES` | Alias for `--targets`. |
| `-t`, `--targets TARGETS` | Identifies the targets of command. |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets. <br> Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@<file>` or stdin `-`. |
| `--rerun FILTER` | Retry on nodes from the last run. <br> `all` runs on all targets from the last run. <br> `failure` runs on all targets that failed in the last run. <br> `success` runs on all targets that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job. |
| `--params PARAMETERS` | Parameters to a task or plan as json, a json file `@<file>`, or on stdin `-`. |
| **Authentication** |
| `-u`, `--user USER` | User to authenticate as. |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. <br> Omit the value to prompt for the password. |
| `--private-key KEY` | Private SSH key to authenticate with. |
| `--[no-]host-key-check` | Check host keys with SSH. |
| `--[no-]ssl` | Use SSL with WinRM. |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM. |
| **Escalation** |
| `--run-as USER` | User to run as using privilege escalation. |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. <br> Omit the value to prompt for the password. |
| **Run Context** |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections. | 100 |
| `--compile-concurrency CONCURRENCY` | Maximum number of simultaneous manifest block compiles. | Number of cores |
| `-m`, `--modulepath FILEPATHS` | List of directories containing modules, separated by `:`. <br> Directories are case-sensitive. |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from. | `~/.puppetlabs/bolt/inventory.yaml` |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| **Transports** |
| `--transport TRANSPORT` | Specify a default transport. <br> `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote` |
| `--connect-timeout TIMEOUT` | Connection timeout. | Varies |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it. |
| `--tmpdir DIR` | The directory to upload and execute temporary files on the target. |
| **Display** |
| `--format FORMAT` | Output format to use. <br> `human`, `json` |
| `--[no-]color` | Whether to show output in color. |
| `-v`, `--[no-]verbose` | Display verbose logging. |
| `--trace` | Display error trace stacks. |


## `plan show`

Show a list of available plans or details for a specific plan.

### Usage

`bolt plan show [PLAN]`

- Specify an available plan to show documentation for the plan.

### Options

| Option | Description | Default |
|--------|-------------|---------|
| **Run Context** |
| `-m`, `--modulepath FILEPATHS` | List of directories containing modules, separated by `:`. <br> Directories are case-sensitive. |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |


## `puppetfile install`

Install modules from a Puppetfile into a Boltdir.

### Usage

`bolt puppetfile install`

- A file named `Puppetfile` must be present in the Boltdir.

### Options

| Option | Description | Default |
|--------|-------------|---------|
| **Run Context** |
| `-m`, `--modulepath FILEPATHS` | List of directories containing modules, separated by `:`. <br> Directories are case-sensitive. |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |


## `puppetfile show-modules`

List modules available to Bolt.

### Usage

`bolt puppetfile show-modules`

### Options

| Option | Description | Default |
|--------|-------------|---------|
| **Run Context** |
| `-m`, `--modulepath FILEPATHS` | List of directories containing modules, separated by `:`. <br> Directories are case-sensitive. |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |


## `script run`

Run a local script on remote targets.

### Usage

`bolt script run <SCRIPT> <TARGETS> [ARGS]`

- You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-n`, `--nodes NODES` | Alias for `--targets`. |
| `-t`, `--targets TARGETS` | Identifies the targets of command. |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets. <br> Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@<file>` or stdin `-`. |
| `--rerun FILTER` | Retry on nodes from the last run. <br> `all` runs on all targets from the last run. <br> `failure` runs on all targets that failed in the last run. <br> `success` runs on all targets that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job. |
| **Authentication** |
| `-u`, `--user USER` | User to authenticate as. |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. <br> Omit the value to prompt for the password. |
| `--private-key KEY` | Private SSH key to authenticate with. |
| `--[no-]host-key-check` | Check host keys with SSH. |
| `--[no-]ssl` | Use SSL with WinRM. |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM. |
| **Escalation** |
| `--run-as USER` | User to run as using privilege escalation. |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. <br> Omit the value to prompt for the password. |
| **Run Context** |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections. | 100 |
| `-m`, `--modulepath FILEPATHS` | List of directories containing modules, separated by `:`. <br> Directories are case-sensitive. |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from. | `~/.puppetlabs/bolt/inventory.yaml` |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| **Transports** |
| `--transport TRANSPORT` | Specify a default transport. <br> `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote` |
| `--connect-timeout TIMEOUT` | Connection timeout. | Varies |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it. |
| `--tmpdir DIR` | The directory to upload and execute temporary files on the target. |
| **Display** |
| `--format FORMAT` | Output format to use. <br> `human`, `json` |
| `--[no-]color` | Whether to show output in color. |
| `-v`, `--[no-]verbose` | Display verbose logging. |
| `--trace` | Display error trace stacks. |


## `secret createkeys`

Create new encryption keys.

### Usage

`bolt secret createkeys`

- Keys are saved to the `keys` directory in the Boltdir.

### Options

| Option | Description | Default |
|--------|-------------|---------|
| **Run Context** |
| `--boltdir FILEPATH` | Specify what Boltdir to save keys to. | Autodiscovered from current working directory. |


## `secret decrypt`

Decrypt a value.

### Usage

`bolt secret decrypt <CIPHERTEXT>`

### Options

| Option | Description | Default |
|--------|-------------|---------|
| **Run Context** |
| `--boltdir FILEPATH` | Specify what Boltdir to load keys from. | Autodiscovered from current working directory. |


## `secret encrypt`

Encrypt a value.

### Usage

`bolt secret encrypt <PLAINTEXT>`

### Options

| Option | Description | Default |
|--------|-------------|---------|
| **Run Context** |
| `--boltdir FILEPATH` | Specify what Boltdir to load keys from. | Autodiscovered from current working directory. |


## `task run`

Run a Puppet task on remote targets.

### Usage

`bolt task run <TASK> <TARGETS>`

- Task parameters are of the form `parameter=value`.
- You must specify one of `--nodes`, `--targets`, `--query`, or `--rerun`.

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-n`, `--nodes NODES` | Alias for `--targets`. |
| `-t`, `--targets TARGETS` | Identifies the targets of command. |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets. <br> Enter a comma-separated list of target URIs or group names. Or read a target list from an input file `@<file>` or stdin `-`. |
| `--rerun FILTER` | Retry on nodes from the last run. <br> `all` runs on all targets from the last run. <br> `failure` runs on all targets that failed in the last run. <br> `success` runs on all targets that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job. |
| `--params PARAMETERS` | Parameters to a task or plan as json, a json file `@<file>`, or on stdin `-`. |
| **Authentication** |
| `-u`, `--user USER` | User to authenticate as. |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. <br> Omit the value to prompt for the password. |
| `--private-key KEY` | Private SSH key to authenticate with. |
| `--[no-]host-key-check` | Check host keys with SSH. |
| `--[no-]ssl` | Use SSL with WinRM. |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM. |
| **Escalation** |
| `--run-as USER` | User to run as using privilege escalation. |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. <br> Omit the value to prompt for the password. |
| **Run Context** |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections. | 100 |
| `--compile-concurrency CONCURRENCY` | Maximum number of simultaneous manifest block compiles. | Number of cores |
| `-m`, `--modulepath FILEPATHS` | List of directories containing modules, separated by `:`. <br> Directories are case-sensitive. |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from. | `~/.puppetlabs/bolt/inventory.yaml` |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| **Transports** |
| `--transport TRANSPORT` | Specify a default transport. <br> `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote` |
| `--connect-timeout TIMEOUT` | Connection timeout. | Varies |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it. |
| `--tmpdir DIR` | The directory to upload and execute temporary files on the target. |
| **Display** |
| `--format FORMAT` | Output format to use. <br> `human`, `json` |
| `--[no-]color` | Whether to show output in color. |
| `-v`, `--[no-]verbose` | Display verbose logging. |
| `--trace` | Display error trace stacks. |


## `task show`

Show a list of available tasks or details for a specific task.

### Usage

`bolt task show [TASK]`

- Specify an available task to show documentation for the task.

### Options

| Option | Description | Default |
|--------|-------------|---------|
| **Run Context** |
| `-m`, `--modulepath FILEPATHS` | List of directories containing modules, separated by `:`. <br> Directories are case-sensitive. |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from. | Autodiscovered from current working directory. |
| `--configfile FILEPATH` | Specify where to load config from. | `~/.puppetlabs/bolt/bolt.yaml` |
