# Adding options to Bolt commands

Bolt commands can accept several command line options, some of which are required.

## Specify targets

Specify the targets that you want Bolt to target.

For most  Bolt commands, you specify targets with the `--targets` flag, for example, `--targets mercury`. For plans, you specify targets as a list within the task plan itself or specify them as regular parameters, like `targets=neptune`.

When targeting systems with the `--targets` flag, you can specify the transport either in the target URL for each host, such as `--targets winrm://mywindowstarget.mydomain`, or set a default transport for the operation with the`--transport` option. If you do not specify a transport it will default to `ssh`.

### Specify targets in the command line

-   To specify multiple targets with the `--targets` flag, use a comma-separated list of targets:
    ```
    --targets neptune,saturn,mars
    ```

-   To generate a target list with brace expansion, specify the target list with an equals sign (`=`), such as `--targets=web{1,2}`.
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

-   To pass targets to Bolt in a file, pass the file name and relative location with the `--targets` flag and an `@` symbol:
    ```
    bolt command run --targets @targets.txt
    ```

    For Windows PowerShell, add single quotation marks to define the file:
    ```
    bolt command run --targets '@targets.txt'
    ```

-   To pass targets on `stdin`, on the command line, use a command to generate a target list, and pipe the result to Bolt with `-` after `--targets`:
    ```
    <COMMAND> | bolt command run --targets -
    ```

    For example, if you have a target list in a text file:
    ```
    cat targets.txt | bolt command run --targets -
    ```

-   To pass targets as IP addresses, use `protocol://user:password@host:port` or inventory group name. You can use a domain name or IP address for `host`, which is required. Other parameters are optional.
    ```
    bolt command run --targets ssh://user:password@[fe80::34eb:ff1:b584:d7c0]:22,
    ssh://root:password@hostname, pcp://host01, winrm://Administrator:password@hostname
    ```


### Specify targets from an inventory file

To specify targets from an inventory file, reference targets by target name, a glob matching names in the file, or the name of a group of targets.
-   To match all targets in both groups listed in the inventory file example:
    ```
    --targets elastic_search,web_app
    ```
-   To match all the targets that start with "elasticsearch" in the inventory file example:
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
-   `remote`

Pass the `--transport` option after the targets list:
```
bolt command run <COMMAND> --targets win1 --transport winrm
```

This sets the transport protocol as the default for this command. If you set this option when running a plan, it is treated as the default transport for the entire plan run. Any targets passed with transports in their URL or transports configured in inventory do not use this default.

This is useful on Windows, so that you do not have to include the `winrm` transport for each target. To override the default transport, specify the protocol on a per-host basis:
```
bolt command run facter --targets win1,ssh://linux --transport winrm
```

If `localhost` is passed to `--targets` when invoking Bolt, the `local` transport is used automatically. To avoid this behavior, prepend the target with the desired transport, for example `ssh://localhost`.


## Specify connection credentials

To manage a target with Bolt, you must specify credentials for a user on the target. You have several options for doing this, depending on which operating system the target is running.

Whether the target runs Linux or Windows, the simplest way to specify credentials is to pass the username and password right in the Bolt command:
```
bolt command run 'hostname' --targets <LINUX_TARGETS> --user <USER> --password <PASSWORD>
```

If you'd prefer to have Bolt securely prompt for a password (so that it won't appear in a process listing or on the console), use the `--password-prompt` option without including a value:
```
bolt command run 'hostname' --targets <LINUX_TARGETS> --user <USER> --password-prompt
```

If the target runs Linux, you can use a username and a public/private key pair instead of a password:
```
bolt command run 'hostname' --targets <LINUX_TARGETS> --user <USER> --private_key <PATH_TO_PRIVATE_KEY>
```

**Tip:** For more information on creating these keys, see [GitHub's clear tutorial](https://help.github.com/en/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).

If the target runs Linux, you can use an SSH configuration file (typically at `~/.ssh/config`) to specify a default username and private key for the remote target.

**Tip:** A good guide to using SSH config files is the [Simplify Your Life With an SSH Config File](https://nerderati.com/2011/03/17/simplify-your-life-with-an-ssh-config-file/) blogpost on the Nerdarati blog.

If the host target runs Linux, the target runs Windows, and your network uses Kerberos for authentication, you can specify a Kerberos realm in your `bolt.yaml` file. This file is introduced in the [Configuring Bolt](configuring_bolt.md) section below. The best source of information and examples for this advanced topic is the [Kerberos section](https://github.com/puppetlabs/bolt/blob/master/developer-docs/kerberos.md) of the Bolt developer documentation.

## Rerunning commands based on the last result

After every execution, Bolt writes information about the result of that run to a `.rerun.json` file inside the Bolt project directory. That file can then be used to specify targets for future commands.

To attempt to retry a failed action on targets, use `--rerun failure`. To continue targeting those targets, pass `--no-save-rerun` to prevent updating the file.
```shell script
bolt command run false --targets all
bolt command run whoami --rerun failure --no-save-rerun
```

If one command is dependent on the success of a previous command, you can target the successful targets with `--rerun success`.
```shell script
bolt task run package action=install name=httpd --targets all
bolt task run server action=restart name=httpd --rerun success
```

**Note:** When a plan does not return a `ResultSet` object, Bolt can't save information for reruns and `.rerun.json` is deleted.

**Related information**  

[Project directories](bolt_project_directories.md#)
