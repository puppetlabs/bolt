# Bolt command reference

These subcommands, actions, and options are available for Bolt.

- [apply](#apply)
- [command run](#command-run)
- [file upload](#file-upload)
- [group show](#group-show)
- [inventory show](#inventory-show)
- [plan convert](#plan-convert)
- [plan run](#plan-run)
- [plan show](#plan-show)
- [puppetfile generate-types](#puppetfile-generate-types)
- [puppetfile install](#puppetfile-install)
- [puppetfile show-modules](#puppetfile-show-modules)
- [script run](#script-run)
- [secret createkeys](#secret-createkeys)
- [secret decrypt](#secret-decrypt)
- [secret encrypt](#secret-encrypt)
- [task run](#task-run)
- [task show](#task-show)


## apply

Usage: bolt apply \<manifest.pp\>

| Option | Description |
| ------ | ----------- |
| `-n`, `--nodes NODES` | Alias for --targets |
| `-t`, `--targets TARGETS` | Identifies the targets of command.<br>Enter a comma-separated list of target URIs or group names.<br>Or read a target list from an input file '@<file>' or stdin '-'.<br>Example: --targets localhost,node_group,ssh://nix.com:23,winrm://windows.puppet.com<br>URI format is [protocol://]host[:port]<br>SSH is the default protocol; may be ssh, winrm, pcp, local, docker, remote<br>For Windows targets, specify the winrm:// protocol if it has not be configured<br>For SSH, port defaults to `22`<br>For WinRM, port defaults to `5985` or `5986` based on the --[no-]ssl setting |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets |
| `--rerun FILTER` | Retry on nodes from the last run<br>'all' all nodes that were part of the last run.<br>'failure' nodes that failed in the last run.<br>'success' nodes that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job |
| `-u`, `--user USER` | User to authenticate as |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. Omit the value to prompt for the password. |
| `--private-key KEY` | Private ssh key to authenticate with |
| `--[no-]host-key-check` | Check host keys with SSH |
| `--[no-]ssl` | Use SSL with WinRM |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM |
| `--run-as USER` | User to run as using privilege escalation |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. Omit the value to prompt for the password. |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections (default: 100) |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml) |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |
| `--transport TRANSPORT` | Specify a default transport: ssh, winrm, pcp, local, docker, remote |
| `--connect-timeout TIMEOUT` | Connection timeout (defaults vary) |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it |
| `--format FORMAT` | Output format to use: human or json |
| `--[no-]color` | Whether to show output in color |
| `-v`, `--[no-]verbose` | Display verbose logging |
| `--trace` | Display error stack traces |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `--noop` | Execute a task that supports it in noop mode |
| `-e`, `--execute CODE` | Puppet manifest code to apply to the targets |
| `--compile-concurrency CONCURRENCY` | Maximum number of simultaneous manifest block compiles (default: number of cores) |



## command run

Usage: bolt command \<action\> \<command\>

| Option | Description |
| ------ | ----------- |
| `-n`, `--nodes NODES` | Alias for --targets |
| `-t`, `--targets TARGETS` | Identifies the targets of command.<br>Enter a comma-separated list of target URIs or group names.<br>Or read a target list from an input file '@<file>' or stdin '-'.<br>Example: --targets localhost,node_group,ssh://nix.com:23,winrm://windows.puppet.com<br>URI format is [protocol://]host[:port]<br>SSH is the default protocol; may be ssh, winrm, pcp, local, docker, remote<br>For Windows targets, specify the winrm:// protocol if it has not be configured<br>For SSH, port defaults to `22`<br>For WinRM, port defaults to `5985` or `5986` based on the --[no-]ssl setting |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets |
| `--rerun FILTER` | Retry on nodes from the last run<br>'all' all nodes that were part of the last run.<br>'failure' nodes that failed in the last run.<br>'success' nodes that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job |
| `-u`, `--user USER` | User to authenticate as |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. Omit the value to prompt for the password. |
| `--private-key KEY` | Private ssh key to authenticate with |
| `--[no-]host-key-check` | Check host keys with SSH |
| `--[no-]ssl` | Use SSL with WinRM |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM |
| `--run-as USER` | User to run as using privilege escalation |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. Omit the value to prompt for the password. |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections (default: 100) |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml) |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |
| `--transport TRANSPORT` | Specify a default transport: ssh, winrm, pcp, local, docker, remote |
| `--connect-timeout TIMEOUT` | Connection timeout (defaults vary) |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it |
| `--format FORMAT` | Output format to use: human or json |
| `--[no-]color` | Whether to show output in color |
| `-v`, `--[no-]verbose` | Display verbose logging |
| `--trace` | Display error stack traces |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |



## file upload

Usage: bolt file \<action\>

| Option | Description |
| ------ | ----------- |
| `-n`, `--nodes NODES` | Alias for --targets |
| `-t`, `--targets TARGETS` | Identifies the targets of command.<br>Enter a comma-separated list of target URIs or group names.<br>Or read a target list from an input file '@<file>' or stdin '-'.<br>Example: --targets localhost,node_group,ssh://nix.com:23,winrm://windows.puppet.com<br>URI format is [protocol://]host[:port]<br>SSH is the default protocol; may be ssh, winrm, pcp, local, docker, remote<br>For Windows targets, specify the winrm:// protocol if it has not be configured<br>For SSH, port defaults to `22`<br>For WinRM, port defaults to `5985` or `5986` based on the --[no-]ssl setting |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets |
| `--rerun FILTER` | Retry on nodes from the last run<br>'all' all nodes that were part of the last run.<br>'failure' nodes that failed in the last run.<br>'success' nodes that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job |
| `-u`, `--user USER` | User to authenticate as |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. Omit the value to prompt for the password. |
| `--private-key KEY` | Private ssh key to authenticate with |
| `--[no-]host-key-check` | Check host keys with SSH |
| `--[no-]ssl` | Use SSL with WinRM |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM |
| `--run-as USER` | User to run as using privilege escalation |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. Omit the value to prompt for the password. |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections (default: 100) |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml) |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |
| `--transport TRANSPORT` | Specify a default transport: ssh, winrm, pcp, local, docker, remote |
| `--connect-timeout TIMEOUT` | Connection timeout (defaults vary) |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it |
| `--format FORMAT` | Output format to use: human or json |
| `--[no-]color` | Whether to show output in color |
| `-v`, `--[no-]verbose` | Display verbose logging |
| `--trace` | Display error stack traces |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `--tmpdir DIR` | The directory to upload and execute temporary files on the target |



## group show

Usage: bolt group \<action\>

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `--format FORMAT` | Output format to use: human or json |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml) |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |



## inventory show

Usage: bolt inventory \<action\>

| Option | Description |
| ------ | ----------- |
| `-n`, `--nodes NODES` | Alias for --targets |
| `-t`, `--targets TARGETS` | Identifies the targets of command.<br>Enter a comma-separated list of target URIs or group names.<br>Or read a target list from an input file '@<file>' or stdin '-'.<br>Example: --targets localhost,node_group,ssh://nix.com:23,winrm://windows.puppet.com<br>URI format is [protocol://]host[:port]<br>SSH is the default protocol; may be ssh, winrm, pcp, local, docker, remote<br>For Windows targets, specify the winrm:// protocol if it has not be configured<br>For SSH, port defaults to `22`<br>For WinRM, port defaults to `5985` or `5986` based on the --[no-]ssl setting |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets |
| `--rerun FILTER` | Retry on nodes from the last run<br>'all' all nodes that were part of the last run.<br>'failure' nodes that failed in the last run.<br>'success' nodes that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `--format FORMAT` | Output format to use: human or json |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml) |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |



## plan convert

Usage: bolt plan convert \<plan_path\>

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |



## plan run

Usage: bolt plan run \<plan\> [parameters]

| Option | Description |
| ------ | ----------- |
| `-n`, `--nodes NODES` | Alias for --targets |
| `-t`, `--targets TARGETS` | Identifies the targets of command.<br>Enter a comma-separated list of target URIs or group names.<br>Or read a target list from an input file '@<file>' or stdin '-'.<br>Example: --targets localhost,node_group,ssh://nix.com:23,winrm://windows.puppet.com<br>URI format is [protocol://]host[:port]<br>SSH is the default protocol; may be ssh, winrm, pcp, local, docker, remote<br>For Windows targets, specify the winrm:// protocol if it has not be configured<br>For SSH, port defaults to `22`<br>For WinRM, port defaults to `5985` or `5986` based on the --[no-]ssl setting |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets |
| `--rerun FILTER` | Retry on nodes from the last run<br>'all' all nodes that were part of the last run.<br>'failure' nodes that failed in the last run.<br>'success' nodes that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job |
| `-u`, `--user USER` | User to authenticate as |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. Omit the value to prompt for the password. |
| `--private-key KEY` | Private ssh key to authenticate with |
| `--[no-]host-key-check` | Check host keys with SSH |
| `--[no-]ssl` | Use SSL with WinRM |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM |
| `--run-as USER` | User to run as using privilege escalation |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. Omit the value to prompt for the password. |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections (default: 100) |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml) |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |
| `--transport TRANSPORT` | Specify a default transport: ssh, winrm, pcp, local, docker, remote |
| `--connect-timeout TIMEOUT` | Connection timeout (defaults vary) |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it |
| `--format FORMAT` | Output format to use: human or json |
| `--[no-]color` | Whether to show output in color |
| `-v`, `--[no-]verbose` | Display verbose logging |
| `--trace` | Display error stack traces |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `--params PARAMETERS` | Parameters to a task or plan as json, a json file '@<file>', or on stdin '-' |
| `--compile-concurrency CONCURRENCY` | Maximum number of simultaneous manifest block compiles (default: number of cores) |
| `--tmpdir DIR` | The directory to upload and execute temporary files on the target |



## plan show

Usage: bolt plan show \<plan\>

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |



## puppetfile generate-types

Usage: bolt puppetfile generate-types

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |



## puppetfile install

Usage: bolt puppetfile install

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |



## puppetfile show-modules

Usage: bolt puppetfile show-modules

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |



## script run

Usage: bolt script \<action\> \<script\> [[arg1] ... [argN]]

| Option | Description |
| ------ | ----------- |
| `-n`, `--nodes NODES` | Alias for --targets |
| `-t`, `--targets TARGETS` | Identifies the targets of command.<br>Enter a comma-separated list of target URIs or group names.<br>Or read a target list from an input file '@<file>' or stdin '-'.<br>Example: --targets localhost,node_group,ssh://nix.com:23,winrm://windows.puppet.com<br>URI format is [protocol://]host[:port]<br>SSH is the default protocol; may be ssh, winrm, pcp, local, docker, remote<br>For Windows targets, specify the winrm:// protocol if it has not be configured<br>For SSH, port defaults to `22`<br>For WinRM, port defaults to `5985` or `5986` based on the --[no-]ssl setting |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets |
| `--rerun FILTER` | Retry on nodes from the last run<br>'all' all nodes that were part of the last run.<br>'failure' nodes that failed in the last run.<br>'success' nodes that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job |
| `-u`, `--user USER` | User to authenticate as |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. Omit the value to prompt for the password. |
| `--private-key KEY` | Private ssh key to authenticate with |
| `--[no-]host-key-check` | Check host keys with SSH |
| `--[no-]ssl` | Use SSL with WinRM |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM |
| `--run-as USER` | User to run as using privilege escalation |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. Omit the value to prompt for the password. |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections (default: 100) |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml) |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |
| `--transport TRANSPORT` | Specify a default transport: ssh, winrm, pcp, local, docker, remote |
| `--connect-timeout TIMEOUT` | Connection timeout (defaults vary) |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it |
| `--format FORMAT` | Output format to use: human or json |
| `--[no-]color` | Whether to show output in color |
| `-v`, `--[no-]verbose` | Display verbose logging |
| `--trace` | Display error stack traces |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `--tmpdir DIR` | The directory to upload and execute temporary files on the target |



## secret createkeys

Usage: bolt secret \<action\> \<value\>

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |
| `--plugin PLUGIN` | Select the plugin to use |



## secret decrypt

Usage: bolt secret \<action\> \<value\>

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |
| `--plugin PLUGIN` | Select the plugin to use |



## secret encrypt

Usage: bolt secret \<action\> \<value\>

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |
| `--plugin PLUGIN` | Select the plugin to use |



## task run

Usage: bolt task run \<task\> [parameters]

| Option | Description |
| ------ | ----------- |
| `-n`, `--nodes NODES` | Alias for --targets |
| `-t`, `--targets TARGETS` | Identifies the targets of command.<br>Enter a comma-separated list of target URIs or group names.<br>Or read a target list from an input file '@<file>' or stdin '-'.<br>Example: --targets localhost,node_group,ssh://nix.com:23,winrm://windows.puppet.com<br>URI format is [protocol://]host[:port]<br>SSH is the default protocol; may be ssh, winrm, pcp, local, docker, remote<br>For Windows targets, specify the winrm:// protocol if it has not be configured<br>For SSH, port defaults to `22`<br>For WinRM, port defaults to `5985` or `5986` based on the --[no-]ssl setting |
| `-q`, `--query QUERY` | Query PuppetDB to determine the targets |
| `--rerun FILTER` | Retry on nodes from the last run<br>'all' all nodes that were part of the last run.<br>'failure' nodes that failed in the last run.<br>'success' nodes that succeeded in the last run. |
| `--description DESCRIPTION` | Description to use for the job |
| `-u`, `--user USER` | User to authenticate as |
| `-p`, `--password [PASSWORD]` | Password to authenticate with. Omit the value to prompt for the password. |
| `--private-key KEY` | Private ssh key to authenticate with |
| `--[no-]host-key-check` | Check host keys with SSH |
| `--[no-]ssl` | Use SSL with WinRM |
| `--[no-]ssl-verify` | Verify remote host SSL certificate with WinRM |
| `--run-as USER` | User to run as using privilege escalation |
| `--sudo-password [PASSWORD]` | Password for privilege escalation. Omit the value to prompt for the password. |
| `-c`, `--concurrency CONCURRENCY` | Maximum number of simultaneous connections (default: 100) |
| `-i`, `--inventoryfile FILEPATH` | Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml) |
| `--[no-]save-rerun` | Whether to update the rerun file after this command. |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |
| `--transport TRANSPORT` | Specify a default transport: ssh, winrm, pcp, local, docker, remote |
| `--connect-timeout TIMEOUT` | Connection timeout (defaults vary) |
| `--[no-]tty` | Request a pseudo TTY on nodes that support it |
| `--format FORMAT` | Output format to use: human or json |
| `--[no-]color` | Whether to show output in color |
| `-v`, `--[no-]verbose` | Display verbose logging |
| `--trace` | Display error stack traces |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `--params PARAMETERS` | Parameters to a task or plan as json, a json file '@<file>', or on stdin '-' |
| `--tmpdir DIR` | The directory to upload and execute temporary files on the target |



## task show

Usage: bolt task show \<task\>

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Display help |
| `--version` | Display the version |
| `--debug` | Display debug logging |
| `-m`, `--modulepath MODULES` | List of directories containing modules, separated by ':'<br>Directories are case-sensitive |
| `--boltdir FILEPATH` | Specify what Boltdir to load config from (default: autodiscovered from current working dir) |
| `--configfile FILEPATH` | Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml) |


