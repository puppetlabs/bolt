---
title: Running Scripts
difficulty: Basic
time: Approximately 5 minutes
---

In this exercise you will run existing scripts against remote nodes using Bolt.

- [Test Linux Nodes for ShellShock](#test-linux-nodes-for-shellshock)
- [Test Windows External Connectivity](#test-windows-external-connectivity)

## Prerequisites
Complete the following before you start this lesson:

- [Installing Bolt](../01-installing-bolt)
- [Setting up test nodes](../02-acquiring-nodes)
- [Running Commands](../03-running-commands)

## Test Linux Nodes for ShellShock
Run the [bashcheck](https://github.com/hannob/bashcheck) script to check on ShellShock and related vulnerabilities.

**Tip:** You likely already have a set of scripts that you run to accomplish common systems administration tasks. Bolt makes it easy to reuse your scripts without modification and to run them quickly across a large number of nodes. Feel free to replace the bashcheck script in this exercise with one of your own. Just set the shebang line correctly and you can run scripts in Python, Ruby, Perl or another scripting language.


Download the `bashcheck.sh` script using `curl`, `wget`,  or similar:

```shell
curl -O https://raw.githubusercontent.com/puppetlabs/bolt/master/docs/_includes/lesson1-10/src/bashcheck.sh
```

Run the script using the command `bolt script run <script-name>`. This uploads the script to the nodes you have specified, ensures it's executable, runs it, and returns output to the console.

```shell
bolt script run src/bashcheck.sh --nodes node1
```

The result:

```
Started on node1...
Finished on node1:
  STDOUT:
    Testing /usr/bin/bash ...
    Bash version 4.2.46(2)-release

    Variable function parser pre/suffixed [(), redhat], bugs not exploitable
    Not vulnerable to CVE-2014-6271 (original shellshock)
    Not vulnerable to CVE-2014-7169 (taviso bug)
    Not vulnerable to CVE-2014-7186 (redir_stack bug)
    Test for CVE-2014-7187 not reliable without address sanitizer
    Not vulnerable to CVE-2014-6277 (lcamtuf bug #1)
    Not vulnerable to CVE-2014-6278 (lcamtuf bug #2)
Successful on 1 node: node1
Ran on 1 node in 0.89 seconds
```

## Test Windows External Connectivity

Create a simple PowerShell script to test connectivity to a known website.

**Tip:** You likely already have a set of scripts that you run to accomplish common systems administration tasks. Bolt makes it easy to reuse your scripts without modification and to run them quickly across a large number of nodes. Feel free to replace the script in this exercise with one of your own.

Save the following as `testconnection.ps1`:

```powershell
{% include lesson1-10/src/testconnection.ps1 -%}
```

Run the script using the command `bolt script run <script-name>`. This uploads the script to the nodes you have specified, ensures it's executable, runs it, and returns output to the console.

```shell
bolt script run src/testconnection.ps1 --nodes windows
```

The result:

```
Started on localhost...
Finished on localhost:
  STDOUT:

    Source        Destination     IPV4Address      IPV6Address                              Bytes    Time(ms)
    ------        -----------     -----------      -----------                              -----    --------
    Nano          example.com                                                               256      4
    Nano          example.com                                                               256      4
    Nano          example.com                                                               256      5


Successful on 1 node: winrm://localhost:55985
Ran on 1 node in 8.55 seconds
```

## Next steps

Now that you know how to use Bolt to run existing scripts you can move on to:

[Writing Tasks](../05-writing-tasks)
