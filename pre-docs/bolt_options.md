# Adding options to Bolt commands

Bolt commands can accept several command line options, some of which are required.

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

-   To pass nodes as IP addresses, use `protocol://user:password@host:port` or inventory group name. You can use a domain name or IP address for `host`, which is required. Other parameters are optional.
    ```
    bolt command run --nodes ssh://user:password@[fe80::34eb:ff1:b584:d7c0]:22,
    ssh://root:password@hostname, pcp://host01, winrm://Administrator:password@hostname
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
```yaml
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

## Set a default transport

To set a default transport protocol, pass it with the command with the `--transport` option.

Available transports are:
-   `ssh`
-   `winrm`
-   `local`
-   `docker`
-   `pcp`

Pass the `--transport` option after the nodes list:
```
bolt command run <COMMAND> --nodes win1 --transport winrm
```

This sets the transport protocol as the default for this command. If you set this option when running a plan, it is treated as the default transport for the entire plan run. Any nodes passed with transports in their URL or transports configured in inventory do not use this default.

This is useful on Windows, so that you do not have to include the `winrm` transport for each node. To override the default transport, specify the protocol on a per-host basis:
```
bolt command run facter --nodes win1,ssh://linux --transport winrm
```

If `localhost` is passed to `--nodes` when invoking Bolt, the `local` transport is used automatically. To avoid this behavior, prepend the target with the desired transport, for example `ssh://localhost`.


## Specify connection credentials

To manage a target node with Bolt, you must specify credentials for a user on the target node. You have several options for doing this, depending on which operating system the target node is running.

Whether the target node runs Linux or Windows, the simplest way to specify credentials is to pass the username and password right in the Bolt command:
```
bolt command run 'hostname' --nodes <LINUX_NODES> --user <USER> --password <PASSWORD>
```

If you'd prefer to have Bolt securely prompt for a password \(so that it won't appear in a process listing or on the console\), use the `--password` option without including a value:
```
bolt command run 'hostname' --nodes <LINUX_NODES> --user <USER> --password
```

If the target node runs Linux, you can use a username and a public/private key pair instead of a password:
```
bolt command run 'hostname' --nodes <LINUX_NODES> --user <USER> --private_key <PATH_TO_PRIVATE_KEY>
```

**Tip:** For more information on creating these keys, see [GitHub's clear tutorial](https://help.github.com/en/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).

If the target node runs Linux, you can use an SSH configuration file \(typically at `~/.ssh/config`\) to specify a default username and private key for the remote node.

**Tip:** A good guide to using SSH config files is the [Simplify Your Life With an SSH Config File](https://nerderati.com/2011/03/17/simplify-your-life-with-an-ssh-config-file/) blogpost on the Nerdarati blog.

If the host node runs Linux, the target node runs Windows, and your network uses Kerberos for authentication, you can specify a Kerberos realm in your `bolt.yaml` file. This file is introduced in the [Configuring Bolt](configuring_bolt.md) section below. The best source of information and examples for this advanced topic is the [Kerberos section](https://github.com/puppetlabs/bolt/blob/master/developer-docs/kerberos.md) of the Bolt developer documentation.

## Rerunning commands based on the last result

After every execution, Bolt writes information about the result of that run to a `.rerun.json` file inside the Bolt project directory. That file can then be used to specify nodes for future commands.

To attempt to retry a failed action on target nodes, use `--rerun failure`. To continue targeting those nodes, pass `--no-save-rerun` to prevent updating the file.
```shell script
bolt command run false --nodes all
bolt command run whoami --rerun failure --no-save-rerun
```

If one command is dependent on the success of a previous command, you can target the successful nodes with `--rerun success`.
```shell script
bolt task run package action=install name=httpd --nodes all
bolt task run server action=restart name=httpd --rerun success
```

**Note:** When a plan does not return a `ResultSet` object, Bolt can't save information for reruns and `.rerun.json` is deleted.

**Related information**  

[Project directories](bolt_project_directories.md#)
