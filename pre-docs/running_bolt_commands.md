
# Running Bolt commands


Bolt executes ad hoc commands, runs scripts, uploads files, and runs Puppet
tasks or task plans on remote nodes from a controller node, such as your laptop
or workstation.

When you run bolt commands, you specify the nodes that you want to execute
commands on. You can also specify your username and password for nodes that
require credentials.

Bolt connects to remote nodes over SSH by default.

To run simple commands or to verify host connectivity, Bolt supports running
commands against a node or nodes.

Example of a cross-platform command:

```
bolt command run "echo 'hello world'"

```

> Note: When connecting to Bolt hosts over WinRM that have not configured SSL for
> port 5986, passing the `--ssl` switch is required to connect to the default WinRM
> port 5985.

## Running arbitrary commands

You can run commands on remote nodes with Bolt.

Specify the command you want to run and which nodes to run it on. Specify nodes
with the node flag, `--nodes` or `-n`:

```
bolt command run <COMMAND> --nodes <NODE>
```

When executing on WinRM nodes, indicate the WinRM protocol in the nodes string:
```
bolt command run <COMMAND> --nodes winrm://<WINDOWS.NODE> --user <USERNAME> --password <PASSWORD>
```

If the command contains spaces or shell special characters, then you must single quote the command:
```
bolt command run 'echo $HOME' --nodes <NODE>
```

## Running scripts

You can execute scripts on remote machines with Bolt.

Bolt copies the script from the local system to the remote node, executes it on
that remote node, and then deletes the script from the remote node.

You can run scripts in any language (such as Bash, PowerShell, or Python), if
the appropriate interpreter is installed on the remote system.

To run on remote *nix systems, the script must include a shebang (`#!`) line
specifying the interpreter. For example, for a script written in Bash, provide
the path to the Bash interpreter:


```bash
#!/bin/bash
echo hello
```

On *nix, Bolt adds execute permissions on the remote system before
executing it. For remote Windows systems, Bolt supports the extensions `.ps1`,
`.rb`, and `.pp`. To enable other file extensions, add them to your Bolt config, as
follows:

```yaml
winrm:
   extensions: [.py, .pl]
```

To run a script, specify the path to the script, and which nodes to run it on.
Specify nodes with node flag, `--nodes` or `-n`:

```
bolt script run <PATH/TO/SCRIPT> --nodes <NODE>
```

When executing on WinRM nodes, include the WinRM protocol in the nodes string:

```
bolt script run <PATH/TO/SCRIPT> --nodes winrm://<NODE> --user <USERNAME> --password <PASSWORD>

```
To pass arguments to a script, specify them after the command, such as `bolt
script run myscript.sh 'echo hello'`. If an argument contain spaces or special
characters, you must quote it. Argument values are passed literally and are not
interpolated by the shell on the remote host, so if you `run bolt script run
myscript.sh 'echo $HOME'`, then the script receives the argument `'echo $HOME'`,
rather than any interpolated value.

## Uploading files
You can use Bolt to copy files to remote nodes.

To upload a file to a remote node, run the bolt file upload command, specifying
the local path to the file and the destination location on the target node, in
the format `bolt file upload <SOURCE> <DESTINATION>`. Specify the nodes with the
`--nodes` flag. For example:

```
bolt file upload my_file.txt /tmp/remote_file.txt --nodes node1,node2
```

Note that most transports are not optimized for file copying, so this is best
limited to small files.