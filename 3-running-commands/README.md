# Running Commands

> **Difficulty**: Basic

> **Time**: Approximately 5 minutes

At the most basic level `bolt` can be used to run arbitrary commands on a set of remote hosts. Let's see that in practice before we move on to more useful higher-level features. In particular we'll look at:

- [Running shell commands on Linux nodes](#running-shell-commands-on-linux-nodes)
- [Running PowerShell commands on Windows nodes](#running-powershell-commands-on-windows-nodes)

Feel free to just run one of these exercises depending on your operating system environment.

# Prerequisites

For the following exercises you should already have `bolt` installed and have a few nodes (either Windows or Linux) available to run commands against. The following guides will help:

1. [Installing Bolt](../1-installing-bolt)
1. [Acquiring nodes](../2-acquiring-nodes)

# Running shell commands on Linux nodes

`bolt` by default uses SSH for transport, and will reuse your existing SSH configuration for authentication. If you can SSH to a node using an SSH another client then `bolt` should just work. That normally means just providing configuration in `~/.ssh/config`. Running a command against a remote node is done with the following:

```
bolt command run <command> --nodes <nodes>
```

Let's run the `uptime` command. Replace `node1` in the following with the address of one of your own nodes.

```
$ bolt command run uptime --nodes node1
Started on node1...
Finished on node1:
  STDOUT:
    21:19:23 up 13 min,  0 users,  load average: 0.08, 0.03, 0.04
```

If you receive an error reading `Host key verification failed` you should make sure the correct host keys are in your `known_hosts` file or pass `--insecure` to future bolt commands. Bolt will not honor `StrictHostKeyChecking` in you ssh config.

`bolt` can also run commands against multiple nodes by passing a command separated list. Replace `node1,node2,node3` in the following with two or more of your own nodes. If you get an error about `Host key verification` run the rest of the examples with the `--insecure` flag to disable host key verification.

```
$ bolt command run uptime --nodes node1,node2,node3
Started on node1...
Started on node2...
Started on node3...
Finished on node1:
  STDOUT:
     21:20:13 up 13 min,  0 users,  load average: 0.20, 0.06, 0.05
Finished on node3:
  STDOUT:
     21:20:14 up 12 min,  0 users,  load average: 0.00, 0.01, 0.02
Finished on node2:
  STDOUT:
     21:20:14 up 13 min,  0 users,  load average: 0.00, 0.01, 0.05$
```

If you're accessing nodes using a username and password rather than keys you can pass those on the command line like so:

```
bolt command run <command> --nodes <node> --user <user> --password <password>
```

`bolt` has a number of other flags. Run the following command to list all of them:

```
bolt --help
```


# Running PowerShell commands on Windows nodes

`bolt` can communicate over WinRM and execute PowerShell commands when running Windows nodes. The command will look like the following:

```
bolt command run <command> --nodes winrm://<node> --user <user> --password <password>
```

Note the `winrm://` prefix for the node address. Also note the `--username` and `--password` flags for passing authentication information. You can see all of the available flags by running:

```
bolt --help
```

If you're trying `bolt` out using Windows run the following command, replacing `node1` with the address of your Windows node. This should list all of the processes running on the remote machine.

```
bolt command run "gps | select ProcessName" --nodes winrm://node1 --user <user> --password <password>
```

The above example accesses a single node. You can also provide a command separated list of nodes like so:

```
bolt command run <command> --nodes winrm://<node>,winrm://<node> --user <user> --password <password>
```

By default `bolt` will use ssl when executing over WinRM.  If you would like to use http use the `--insecure` flag.  
```
bolt command run <command> --insecure --nodes winrm://<node>,winrm://<node> --user <user> --password <password>
```
# Next steps

Now you know how to run adhoc commands with `bolt` you can move on to:

1. [Running Scripts](../4-running-scripts)
