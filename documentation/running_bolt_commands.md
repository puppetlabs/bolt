# Running basic Bolt commands

Use Bolt commands to connect directly to the systems where you want to execute
commands, run scripts, and upload files.

## Run a command on remote targets

Specify the command you want to run and which targets to run it on.

When you have credentials on remote systems, you can use Bolt to run commands
across those systems.

-   To run a command on a list of targets:
    ```shell script
    bolt command run <COMMAND> --targets <TARGET NAME>,<TARGET NAME>,<TARGET NAME>
    ```
-   To run a command on WinRM targets, indicate the WinRM protocol in the
    targets string:
    ```shell script
    bolt command run <COMMAND> --targets winrm://<WINDOWS.TARGET> --user <USERNAME> --password <PASSWORD>
    ```
-   To run a command that contains spaces or shell special characters, wrap the
    command in single quotation marks:
    ```shell script
    bolt command run 'echo $HOME' --targets web5.mydomain.edu,web6.mydomain.edu
    ```
    ```shell script
    bolt command run "netstat -an | grep 'tcp.*LISTEN'" --targets web5.mydomain.edu,web6.mydomain.edu
    ```
-   To run a cross-platform command:
    ```shell script
    bolt command run "echo 'hello world'"
    ```

    **Note:** When connecting to Bolt hosts over WinRM that have not configured
    SSL for port 5986, passing the `--no-ssl` switch is required to connect to
    the default WinRM port 5985.


## Running commands with redirection or pipes

When you run one-line commands that include redirection or pipes, pass `bash` or
another shell as the command.

Using a shell ensures that the one-liner is run as a single command and that it
works correctly with `run-as`. For example, instead of `bolt command run "echo
foo > /root/foo" --run-as root`, use `bolt command run "bash -c 'echo foo >
/root/foo'" --run-as root`.

## Run a script on remote targets

Specify the script you want to run and which targets to run it on.

Use the `bolt script run` command to run existing scripts that you use or to
combine the commands that you regularly run as part of sequence. When you run a
script with Bolt, the script is transferred into a temporary directory on the
remote system, run on that system, and then deleted.

You can run scripts in any language as long as the appropriate interpreter is
installed on the remote system. This includes Bash, PowerShell, or Python.

-   To run a script, specify the path to the script, and which targets to run it
    on:
    ```shell script
    bolt script run <PATH/TO/SCRIPT> --targets <TARGET NAME>,<TARGET NAME>,<TARGET NAME>
    ```
    ```shell script
    bolt script run ../myscript.sh --targets web5.mydomain.edu,web6.mydomain.edu
    ```
-   When executing on WinRM targets, include the WinRM protocol in the targets
    string:
    ```shell script
    bolt script run <PATH/TO/SCRIPT> --targets winrm://<TARGET NAME> --user <USERNAME> --password <PASSWORD>
    ```
-   To pass arguments to a script, specify them after the command. If an
    argument contain spaces or special characters, you must quote it:
    ```shell script
    bolt script run myscript.sh 'echo hello'
    ```
    Argument values are passed literally and are not interpolated by the shell
    on the remote host. If you run `bolt script run myscript.sh 'echo $HOME'`,
    then the script receives the argument `'echo $HOME'`, rather than any
    interpolated value.
-   To pass arguments prefixed with `-` to a script, use the following syntax:
    ```shell script
    bolt script run <BOLT_ARGUMENTS> <SCRIPT_NAME> -- <SCRIPT_ARGUMENTS>
    ```
    For example, 
    ```shell script
    bolt script run -t targets -u user myscript.sh -- --script-param --foo bar
    ```

### Requirements for scripts run on remote \*nix systems

A script must include a shebang (`#!`) line specifying the interpreter. For
example, for a script written in Bash, provide the path to the Bash interpreter:

```shell script
#!/bin/bash
echo hello
```

### Requirements for scripts run on remote Windows systems

Bolt supports the extensions `.ps1`, `.rb`, and `.pp`. To enable other file
extensions, add them to your Bolt configuration file, as follows:

```yaml
winrm:
   extensions: [.py, .pl]
```

## Upload files or directories to remote targets

Use Bolt to copy files or directories to remote targets.

**Note:** Most transports are not optimized for file copying, so this command is
best limited to small files.

-   To upload a file or directory to a remote target, run the `bolt file upload`
    command. Specify the local path to the file or directory, the destination
    location, and the targets.

    ```
    bolt file upload <SOURCE> <DESTINATION> --targets <TARGET NAME>,<TARGET NAME>
    ```

    ```
    bolt file upload my_file.txt /tmp/remote_file.txt --targets web5.mydomain.edu,web6.mydomain.edu
    ```

## Download files or directories from remote targets

Use Bolt to copy files or directories from remote targets to your local system.

To download a file or directory from a remote target, run the
`bolt file download` command. Specify the remote path to the file or
directory, the destination directory on your local system, and the targets.

```shell
$ bolt file download <SOURCE> <DESTINATION> --targets <TARGETS>
```

The `destination` can be either an absolute or relative path to a directory
on your local system. If you use a relative path, Bolt expands the path
relative to the current working directory. If the destination directory does
not exist, Bolt will automatically create it.

Each file or directory is saved to the destination directory under a
directory with a name matching the URL-encoded name of the target it
was downloaded from. The target directory names are URL-encoded to ensure
that they are valid directory names.

For example, the following command downloads the SSH daemon configuration 
file from two targets, `linux` and `ssh://example.com`:

```shell
$ bolt file download /etc/ssh/sshd_config sshd_config --targets linux,ssh://example.com
```

After running this command from the root of your project directory, your
project directory structure would look like this:

```shell
$ tree
.
├── bolt-project.yaml
├── inventory.yaml
└── downloads/
    └── sshd_config/
        ├── linux/
        │   └── sshd_config
        └── ssh%3A%2F%2Fexample.com/
            └── sshd_config
```

> 🔩 **Tip:** To avoid URL encoding the target's safe name, give the target a
> simple, human-readable name in your inventory file.

## Adding options to Bolt commands

Bolt commands can accept several command line options, some of which are
required.

### Specify targets

Specify the targets that you want Bolt to target.

For most  Bolt commands, you specify targets with the `--targets` flag, for
example, `--targets mercury`. For plans, you specify targets as a list within
the task plan itself or specify them as regular parameters,
like `targets=neptune`.

When targeting systems with the `--targets` flag, you can specify the transport
either in the target URL for each host, such as `--targets
winrm://mywindowstarget.mydomain`, or set a default transport for the operation
with the`--transport` option. If you do not specify a transport it will default
to `ssh`.

#### Specify targets in the command line

-   To specify multiple targets with the `--targets` flag, use a comma-separated
    list of targets:
    ```
    --targets neptune,saturn,mars
    ```

-   To generate a target list with brace expansion, specify the target list with
    an equals sign (`=`), such as `--targets=web{1,2}`.
    ```
     bolt command run --targets={web{5,6,7},elasticsearch{1,2,3}.subdomain}.mydomain.edu  
    ```
    This command runs Bolt on the following hosts:
    -   elasticsearch1.subdomain.mydomain.edu
    -   elasticsearch2.subdomain.mydomain.edu
    -   elasticsearch3.subdomain.mydomain.edu
    -   web5.mydomain.edu
    -   web6.mydomain.edu
    -   web7.mydomain.edu

-   To pass targets to Bolt in a file, pass the file name and relative location
    with the `--targets` flag and an `@` symbol:
    ```
    bolt command run --targets @targets.txt
    ```

    For Windows PowerShell, add single quotation marks to define the file:
    ```
    bolt command run --targets '@targets.txt'
    ```

-   To pass targets on `stdin`, on the command line, use a command to generate a
    target list, and pipe the result to Bolt with `-` after `--targets`:
    ```
    <COMMAND> | bolt command run --targets -
    ```

    For example, if you have a target list in a text file:
    ```
    cat targets.txt | bolt command run --targets -
    ```

-   To pass targets as IP addresses, use `protocol://user:password@host:port` or
    inventory group name. You can use a domain name or IP address for `host`,
    which is required. Other parameters are optional.
    ```
    bolt command run --targets ssh://user:password@[fe80::34eb:ff1:b584:d7c0]:22,
    ssh://root:password@hostname, pcp://host01, winrm://Administrator:password@hostname
    ```


#### Specify targets from an inventory file

To specify targets from an inventory file, reference targets by target name, a
glob matching names in the file, or the name of a group of targets.
-   To match all targets in both groups listed in the inventory file example:
    ```
    --targets elastic_search,web_app
    ```
-   To match all the targets that start with "elasticsearch" in the inventory
    file example:
    ```
    --targets 'elasticsearch*' 
    ```

This inventory file defines two top-level groups: elastic_search and web_app.
```yaml
groups:
  - name: elastic_search
    targets:
      - elasticsearch1.subdomain.mydomain.edu
      - elasticsearch2.subdomain.mydomain.edu
      - elasticsearch3.subdomain.mydomain.edu
  - name: web_app
    targets:
      - web5.mydomain.edu
      - web6.mydomain.edu
      - web7.mydomain.edu
```

📖 **Related information**  

[Inventory file](inventory_file_v2.md)

### Set a default transport

To set a default transport protocol, pass it with the command with the
`--transport` option.

Available transports are:
-   `ssh`
-   `winrm`
-   `local`
-   `docker`
-   `pcp`

Pass the `--transport` option after the targets list:
```
bolt command run <COMMAND> --targets win1 --transport winrm
```

This sets the transport protocol as the default for this command. If you set
this option when running a plan, it is treated as the default transport for the
entire plan run. Any targets passed with transports in their URL or transports
configured in inventory do not use this default.

This is useful on Windows, so that you do not have to include the `winrm`
transport for each target. To override the default transport, specify the
protocol on a per-host basis:
```
bolt command run facter --targets win1,ssh://linux --transport winrm
```

If `localhost` is passed to `--targets` when invoking Bolt,
the `local` transport is used automatically. To avoid this behavior, prepend the
target with the desired transport, for example `ssh://localhost`.


### Specify connection credentials

To manage a target with Bolt, you must specify credentials for a user on the
target. You have several options for doing this, depending on which operating
system the target is running.

Whether the target runs Linux or Windows, the simplest way to specify
credentials is to pass the username and password right in the Bolt command:
```
bolt command run 'hostname' --targets <LINUX_TARGETS> --user <USER> --password <PASSWORD>
```

If you'd prefer to have Bolt securely prompt for a password (so that it won't
appear in a process listing or on the console), use the `--password-prompt`
option without including a value:
```
bolt command run 'hostname' --targets <LINUX_TARGETS> --user <USER> --password-prompt
```

If the target runs Linux, you can use a username and a public/private key pair
instead of a password:
```
bolt command run 'hostname' --targets <LINUX_TARGETS> --user <USER> --private_key <PATH_TO_PRIVATE_KEY>
```

> 🔩 **Tip:** For more information on creating these keys, see [GitHub's clear
> tutorial](https://help.github.com/en/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).

If the target runs Linux, you can use an SSH configuration file (typically at
`~/.ssh/config`) to specify a default username and private key for the remote
target.

> 🔩 **Tip:** A good guide to using SSH config files is the [Simplify Your Life
> With an SSH Config
> File](https://nerderati.com/2011/03/17/simplify-your-life-with-an-ssh-config-file/)
> blogpost on the Nerdarati blog.

If the host target runs Linux, the target runs Windows, and your network uses
Kerberos for authentication, you can specify a Kerberos realm in your
[inventory file](inventory_file_v2.md). The best source of information and
examples for this advanced topic is the [Kerberos
section](https://github.com/puppetlabs/bolt/blob/main/developer-docs/kerberos.md)
of the Bolt developer documentation.

### Rerunning commands based on the last result

After every execution, Bolt writes information about the result of that run to a
`.rerun.json` file inside the Bolt project directory. That file can then be used
to specify targets for future commands.

To attempt to retry a failed action on targets, use `--rerun failure`. To
continue targeting those targets, pass `--no-save-rerun` to prevent updating the
file.
```shell script
bolt command run false --targets all
bolt command run whoami --rerun failure --no-save-rerun
```

If one command is dependent on the success of a previous command, you can target
the successful targets with `--rerun success`.
```shell script
bolt task run package action=install name=httpd --targets all
bolt task run server action=restart name=httpd --rerun success
```

**Note:** When a plan does not return a `ResultSet` object, Bolt can't save
information for reruns and `.rerun.json` is deleted.

📖 **Related information**  

[Project directories](bolt_project_directories.md#)
