# Bolt configuration options

Your Bolt configuration file can contain global and transport options.

**Related Information**

[Bolt project directory](./bolt_project_directory.md)

## Sample Bolt configuration file

```
modulepath: "~/.puppetlabs/bolt-code/modules:~/.puppetlabs/bolt-code/site-modules"
inventoryfile: "~/.puppetlabs/bolt/inventory.yaml"
concurrency: 10
format: human
ssh:
  host-key-check: false
  private-key: ~/.ssh/bolt_id
  user: foo
  interpreters:
    rb: /home/foo/.rbenv/versions/2.5.1/bin/ruby
```

## Global configuration options

`color`: Whether to use colored output when printing messages to the console.

`concurrency`: The number of threads to use when executing on remote nodes. Default is `100`.

`format`: The format to use when printing results. Options are `human` and `json`. Default is `human`.

`hiera-config`: Specify the path to your Hiera config. The default path for the Hiera config file is `hiera.yaml` inside the Bolt project directory.

`interpreters`: A map of an extension name to the absolute path of an executable, enabling you to override the shebang defined in a task executable. The extension can optionally be specified with the '.' character ('.py' and 'py' both map to a task executable `task.py`) and the extension is case sensitive. The transports that support interpreter configuration are `docker`, `local`, `ssh`, and `winrm`. When a node's name is `localhost` ruby tasks are run with Bolt's ruby interpreter by default. The following example demonstrates configuring python tasks to be run with a python3 interpreter:

```
interpreters:
  py: /usr/bin/python3
```

`inventoryfile`: The path to a structured data inventory file used to refer to groups of nodes on the commandline and from plans. The default path for the inventory file is `inventory.yaml` inside the Bolt project directory.

`puppetfile`: A map containing options for the `bolt puppetfile install` command. The allowed keys are detailed below.

`modulepath`: The module path for loading tasks and plan code. This is either an array of directories or a string containing a list of directories separated by the OS specific PATH separator. The default path for modules is `modules:site-modules:site` inside the Bolt project directory.

`transport`: Specify the default transport to use when the transport for a target is not specified in the url or inventory. The valid options for transport are `docker`, `local`, `pcp`, `ssh`, and `winrm`.

`save-rerun`: Whether bolt should update `.rerun.json` in the [Bolt project
directory]. If your target names include passwords you should set this to false
to avoid writing them to disk.

## SSH transport configuration options

`connect-timeout`: How long Bolt should wait when establishing connections.

`host-key-check`: Whether to perform host key validation when connecting over SSH. Default is `true`.

`password`: Login password.

`port`: Connection port. Default is `22`.

`private-key`: The path to the private key file to use for SSH authentication.

`proxyjump`: A jump host to proxy ssh connections through and an optional user to connect as for example `jump.example.com` or `user1@jump.example.com`.

`run-as`: A different user to run commands as after login.

`run-as-command`: The command to elevate permissions. Bolt appends the user and command strings to the configured run as a command before running it on the target. This command must not require an interactive password prompt, and the `sudo-password` option is ignored when `run-as-command` is specified. The run-as command must be specified as an array.

`sudo-password`: Password to use when changing users via `run-as`.

`tmpdir`: The directory to upload and execute temporary files on the target.

`user`: Login user. Default is `root`.

### OpenSSH configuration options 

In addition to the ssh transport options defined in Bolt-specific configuration files some additional ssh options are read from OpenSSH configuration files ( `~/.ssh/config`, `/etc/ssh_config`, and `/etc/ssh/ssh_config`). Not all OpenSSH configuration values have equivalents in Bolt. Below is a list of options configurable in OpenSSH files.
 
- `Ciphers`: Ciphers allowed in order of preference. Multiple ciphers must be comma-separated.
- `Compression`: Whether to use compression.
- `CompressionLevel`: Compression level to use if compression is enabled.
- `GlobalKnownHostsFile`: Path to global host key database.
- `HostKeyAlgorithms`: Host key algorithms that the client wants to use in order of preference.
- `HostKeyAlias`: Use alias instead of real host name when looking up or saving the host key in the host key database file.
- `IdentitiesOnly`: Only use Identity Key in ssh config even if ssh-agent offers others.
- `HostName`: Host name to log.
- `IdentityFile`: File which user's identity key is stored.
- `Port`: SSH port.
- `UserKnownHostsFile`: Path to local user's host key database.

**Note**: For OpenSSH configuration options with direct equivalents in Bolt (for example `user` and `port`) the setting in Bolt config take precedence. 

In order to illustrate consider the following example:

inventory.yaml
```yaml
nodes:
  - name: host1.example.net
    config:
      transport: ssh
      ssh:
        host-key-check: true
        port: 22
        private-key: /.ssh/id_rsa-example
```
\~/.ssh/config
```
Host *.example.net
  UserKnownHostsFile=~/.ssh/known_hosts
  User root
  Port 444
```
The ssh connection will be configured to use the user and known hosts file defined in OpenSSH config and the port defined in Bolt config. Note that `host-key-check` must be set in Bolt config (the `StrictHostKeyChecking` OpenSSH configuration value is ignored). 

When using the ssh transport Bolt also interacts with the ssh-agent for ssh key management. The most common interaction is to handle password protected private keys. When a private key is password protected it must be added to the ssh-agent in order to be used to authenticate Bolt ssh connections.

## WinRM transport configuration options

`cacert`: The path to the CA certificate.

`connect-timeout`: How long Bolt should wait when establishing connections.

`extensions`: List of file extensions that are accepted for scripts or tasks. Scripts with these file extensions rely on the target node's file type association to run. For example, if Python is installed on the system, a `.py` script should run with `python.exe`. The extensions .`ps1`, `.rb`, and `.pp` are always allowed and run via hard-coded executables.

`file-protocol`: Which file transfer protocol to use. Either `winrm` or `smb`. Using `smb` is recommended for large file transfers. Default is `winrm`.

**Note**: The SMB file protocol is experimental and is currently unsupported in conjunction with SSL given that only SMB2 is currently implemented.

`password`: Login password. Required.

`port`: Connection port. Default is `5986`, or `5985` if `ssl: false`.

`smb-port`: With `file-protocol` set to `smb`, this is the port to establish a connection on. Default is `445`.

`ssl`: When `true`, Bolt will use secure https connections for WinRM. Default is `true`.

`ssl-verify`: When true, verifies the targets certificate matches the `cacert`. Default is `true`.

`tmpdir`: The directory to upload and execute temporary files on the target.

`user`: Login user. Required.


## PCP transport configuration options

`cacert`: The path to the CA certificate.

`service-url`: The URL of the orchestrator API.

`task-environment`: The environment orchestrator should load task code from.

`token-file`: The path to the token file.


## Local transport configuration options

`tmpdir`: The directory to copy and execute temporary files.
`run-as`: A different user to run commands as after login.

`run-as-command`: The command to elevate permissions. Bolt appends the user and command strings to the configured run as a command before running it on the target. This command must not require an interactive password prompt, and the `sudo-password` option is ignored when `run-as-command` is specified. The run-as command must be specified as an array.

`sudo-password`: Password to use when changing users via `run-as`.

## Docker transport configuration options

*The Docker transport is experimental as the capabilities and role of the Docker API may change*

`service-options`: A hash of options to configure the Docker connection. Only necessary if using a non-default URL. See https://github.com/swipely/docker-api for supported options.

`service-url`: URL of the Docker host used for API requests. Defaults to local via a unix socket at `unix:///var/docker.sock`.

`tmpdir`: The directory to upload and execute temporary files on the target.

`shell-command`: A shell command any docker exec commands should be wrapped in. For example: `bash -lc`.

`tty`: When `true`, enable tty on docker exec commands. Default is `false`.

## Remote transport configuration options

*The remote transport is a new feature and currently experimental. It's configuration options and behavior may change between y releases*

The remote transport can accept arbitrary option that depend on the underlying remote target for example `api-token`.

`run-on`: The proxy target the task should execute on. Default is `localhost`


## Log file configuration options

Capture the results of your plan runs in a log file.

`log`: the configuration of the log file output. This option includes the following properties:

-   `append` add output to an existing log file. Available for only for logs output to a filepath. Your options are `true` \(default\) and `false`.
-   `console` or `path/to.log`: the location of the log output.
-   `level`: the type of information in the log. Your options are `debug`, `info`, `notice`, `warn`, and `error`.



```
log:
  console:
    level: info
  ~/.bolt/debug.log:
    level: debug
    append: false

```

## Puppetfile configuration options

The `puppetfile` section configures how modules are retrieved when running `bolt puppetfile install`.

`proxy`: The HTTP proxy to use for Git and Puppet Forge operations

`forge`: A subsection which can have its own `proxy` setting to set an HTTP proxy for only Puppet Forge operations, and a `baseurl` setting to specify a different Forge host
