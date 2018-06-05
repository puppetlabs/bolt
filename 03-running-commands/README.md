# Running Commands

> **Difficulty**: Basic

> **Time**: Approximately 5 minutes

You can use Bolt to run arbitrary commands on a set of remote hosts. Let's see that in practice before we move on to more advanced features. Choose the exercise based on the operating system of your test nodes.

- [Running shell commands on Linux nodes](#running-shell-commands-on-linux-nodes)
- [Running PowerShell commands on Windows nodes](#running-powershell-commands-on-windows-nodes)

# Prerequisites
Complete the following before you start this lesson:

1. [Installing Bolt](../01-installing-bolt)
1. [Setting up test nodes](../02-acquiring-nodes)

# Running shell commands on Linux nodes

Bolt by default uses SSH for transport. If you can connect to systems remotely, you can use Bolt to run shell commands. It reuses your existing SSH configuration for authentication, which is typically provided in `~/.ssh/config`.

To run a command against a remote Linux node, use the following command syntax:
```
bolt command run <command> --nodes <nodes>
```

To run a command against a remote node using a username and password rather than keys use the following syntax:
```
bolt command run <command> --nodes <nodes> --user <user> --password <password>
```

1. Run the `uptime` command to view how long the system has been running. If you are using existing nodes on your system, replace `node1` with the address for your node.

    ```
    bolt command run uptime --nodes node1
    ```
    The result:
    ```
    Started on node1...
    Finished on node1:
        STDOUT:
         00:20:55 up 19 min,  0 users,  load average: 0.00, 0.01, 0.03
    Successful on 1 node: node1
    Ran on 1 node in 0.43 seconds
    ```

    **Tip:** If you receive the error `Host key verification failed` make sure the correct host keys are in your `known_hosts` file or pass `--no-host-key-check` to future Bolt commands. Bolt will not honor `StrictHostKeyChecking` in your SSH configuration.

2. Run the 'uptime' command on multiple nodes by passing a comma-separated list. If you are using existing nodes on your system, replace `node1,node2,node3` with addresses for your nodes. If you get an error about `Host key verification` run the rest of the examples with the `--no-host-key-check` flag to disable host key verification.

    ```
    bolt command run uptime --nodes node1,node2,node3
    ```
    The result:
    ```
    Started on node2...
    Started on node1...
    Started on node3...
    Finished on node2:
      STDOUT:
         00:21:53 up 19 min,  0 users,  load average: 0.00, 0.01, 0.03
    Finished on node3:
      STDOUT:
         00:21:53 up 18 min,  0 users,  load average: 0.02, 0.04, 0.04
    Finished on node1:
      STDOUT:
         00:21:53 up 19 min,  0 users,  load average: 0.00, 0.01, 0.03
    Successful on 3 nodes: node1,node2,node3
    Ran on 3 nodes in 0.50 seconds

    ```

3. Create an inventory file to store information about your nodes and refer to them as a group.  Later exercises will refer to the default group `all`. For more information on how to set up other named groups, see the
    [Inventory File docs](https://puppet.com/docs/bolt/0.x/inventory_file.html).

    For example, if you are using the provided Vagrant configuration file, save the following to `~/.puppetlabs/bolt/inventory.yaml`:

    ```yaml
    nodes: [node1, node2, node3]
    ```

    If you're accessing nodes using a username and password rather than keys, save the following to `~/.puppetlabs/bolt/inventory.yaml`:

    ```yaml
    nodes: [node1, node2, node3]
    config:
      transports:
        ssh:
          user: $user
          password: $password
    ```

# Running PowerShell commands on Windows nodes

Bolt can communicate over WinRM and execute PowerShell commands when running Windows nodes. To run a command against a remote Windows node, use the following command syntax:

```
bolt command run <command> --nodes winrm://<node> --user <user> --password <password>
```

Note the `winrm://` prefix for the node address. Also note the `--username` and `--password` flags for passing authentication information. In addition, unless you have set up SSL for WinRM communication, you must supply the `--no-ssl` flag. Otherwise running a Bolt command will result in an `unknown protocol` error.

```
bolt command run <command> --no-ssl --nodes winrm://<node>,winrm://<node> --user <user> --password <password>
```

1. Set a variable with the list of nodes.  Later exercises will refer to this variable. You can incorporate the username and password into the node address. For example, if you are using the provided Vagrant configuration file, set the following:

    ```
    WINNODE=winrm://vagrant:vagrant@localhost:55985
    ```

    On Windows, you can do the same thing with Powershell:

    ```powershell
    $WINNODE="winrm://vagrant:vagrant@localhost:55985"
    ```

2.  Run the following command to list all of the processes running on a remote machine.

    ```
    bolt command run "gps | select ProcessName" --nodes $WINNODE
    ```

    Use following syntax to list all of the processes running on multiple remote machines.

    ```
    bolt command run <command> --nodes winrm://<node>,winrm://<node> --user <user> --password <password>
    ```


# Next steps

Now that you know how to use Bolt to run adhoc commands you can move on to:

[Running Scripts](../04-running-scripts)
