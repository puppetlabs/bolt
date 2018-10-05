# Adding options to Bolt commands

Bolt commands can accept several command line options, some of which are required.

Task commands, such as `bolt run task` and `bolt run plan`, require the `--modules` flag to specify the location of the task or plan module on the workstation you are running the command from.

## Specify target nodes

Specify the nodes that you want Bolt to target.

For most  Bolt commands, you specify target nodes with the `--nodes` flag, for example, `--nodes mercury`. For plans, you specify nodes as a list within the task plan itself or specify them as regular parameters, like `nodes=neptune`.

When targeting systems with the `--nodes` flag, you can specify the transport either in the node URL for each host, such as `--nodes winrm://mywindowsnode.mydomain`, or set a default transport for the operation with the`--transport` option. If you do not specify a transport it will default to `ssh`.

### Specify nodes in the command line

-   To specify multiple nodes with the `--nodes` flag, use a comma-separated list of nodes:

```
--nodes neptune,saturn,mars
```

-   To generate a node list with brace expansion, specify the node list with an equals sign \(`=`\), such as `--nodes=web{1,2}`.

    ```
     bolt command run --nodes={web{5,6,7},elasticsearch{1,2,3}.subdomain}.mydomain.edu  
    ```

    This command runs Bolt on the following hosts:

    -   elasticsearch1.subdomain.mydomain.edu

    -   elasticsearch2.subdomain.mydomain.edu

    -   elasticsearch3.subdomain.mydomain.edu

    -   web5.mydomain.edu

    -   web6.mydomain.edu

    -   web7.mydomain.edu

-   To pass nodes to Bolt in a file, pass the file name and relative location with the `--nodes` flag and an `@` symbol:

    ```
    bolt command run --nodes @nodes.txt
    ```

    For Windows PowerShell, add single quotation marks to define the file:

    ```
    bolt command run --nodes '@nodes.txt'
    ```

-   To pass nodes on `stdin`, on the command line, use a command to generate a node list, and pipe the result to Bolt with `-` after `--nodes`:

```
<COMMAND> | bolt command run --nodes -
```

    For example, if you have a node list in a text file:

    ```
    cat nodes.txt | bolt command run --nodes -
    ```


### Specify nodes from an inventory file

To specify nodes from an inventory file, reference nodes by node name, a glob matching names in the file, or the name of a group of nodes.

-   To match all nodes in both groups listed in the inventory file example:

```
--nodes elastic_search,web_app
```

-   To match all the nodes that start with elasticsearch in the inventory file example:

```
--nodes 'elasticsearch*' 
```


This inventory file defines two top-level groups: elastic\_search and web\_app.

```
groups:
  - name: elastic_search
    nodes:
      - elasticsearch1.subdomain.mydomain.edu
      - elasticsearch2.subdomain.mydomain.edu
      - elasticsearch3.subdomain.mydomain.edu
  - name: web_app
    nodes:
      - web5.mydomain.edu
      - web6.mydomain.edu
      - web7.mydomain.edu
```

**Related information**  


[Inventory file](inventory_file.md)

### Set a default transport

To set a default transport protocol, pass it with the command with the `--transport` option.

Pass the `--transport` option after the nodes list:

```
bolt command run <COMMAND> --nodes win1 --transport winrm
```

This sets the transport protocol as the default for this command. If you set this option when running a plan, it is treated as the default transport for the entire plan run. Any nodes passed with transports in their URL or transports configured in inventory will not use this default.

This is useful on Windows, so that you do not have to include the `winrm` transport for each node. To override the default transport, specify the protocol on a per-host basis:

```
bolt command run facter --nodes win1,ssh://linux --transport winrm
```

If `localhost` is passed to `--nodes` when invoking Bolt on a non-Windows operating system the `local` transport is used automatically. To avoid this behavior prepend the target with the desired transport, for example `ssh://localhost`.

## Specify connection credentials

To run Bolt on target nodes that require a username and password, pass credentials as options on the command line.

Bolt connects to remote nodes with either SSH or WinRM.

You can manage SSH connections with an SSH configuration file \(`~/.ssh/config`\) on your workstation, or you can specify the username and password on the command line.

WinRM connections always require you to pass the username and password with the `bolt` command:

```
bolt command run 'gpupdate /force' --nodes winrm://pluto --user Administrator --password <PASSWORD>
```

To have Bolt securely prompt for a password, use the `--password` or `-p` flag without supplying any value. Bolt will then prompt for the password, so that it does not appear in a process listing or on the console. 

## Specify the module path

When executing tasks or plans, you must specify the `--modulepath` option as the directory containing the task modules.

Specify this option in the format `--modulepath </PATH/TO/MODULE>` . This path should be only the path the modules directory, such as `~/modules`. Do not specify the module name in this path, as the name is already specified as part of the task or plan name.

To specify multiple module directories to search for modules, separate the paths with a semicolon \(`;`\) on Windows or a colon \(`:`\) on all other platforms.

