# Running Scripts

> **Difficulty**: Basic

> **Time**: Approximately 5 minutes

In this exercise you will run existing scripts against remote nodes using `bolt`.

- [Test Linux nodes for ShellShock](#test-linux-nodes-for-shellshock)
- [Test Windows external connectivity](#test-windows-external-connectivity)

# Prerequisites

For the following exercises you should already have `bolt` installed and have a few nodes (either Windows or Linux) available to run commands against. The following guides will help:

1. [Installing Bolt](../1-installing-bolt)
1. [Acquiring nodes](../2-acquiring-nodes)

It is also useful to have some familiarity with running commands with `bolt` so you understand passing nodes and credentials. The following exercise is recommended:

1. [Running Commands](../3-running-commands)

# Test Linux nodes for ShellShock

You likely already have a set of scripts which you run to accomplish common systems administration tasks. `bolt` makes it easy to reuse those scripts without modification, and to run them quickly across a large number of nodes. Feel free to use an existing script of you have one in mind, if not let's use the excellent [bashcheck](https://github.com/hannob/bashcheck) script for checking on ShellShock and related vulnerabilities.

You can download `bashcheck` using `wget` or similar like so:

```
curl -O https://raw.githubusercontent.com/hannob/bashcheck/master/bashcheck
```

Next we run the script using `bolt script run <script-name>`. This will upload the script specified to all specified nodes, ensure it's executable and finally run it, returning the output to the console. An example of running that with `bashcheck` looks like:

```
$ bolt script run bashcheck -n $NODE
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
Ran on 1 node in 0.41 seconds
```

`bashcheck` is a bash script, but `bolt` will happily upload and run any script which is runnable on the specified nodes. Just set the shebang line correctly and you can run Python scripts, Ruby scripts, Perl scripts or anything else.


# Test Windows external connectivity

You likely already have a set of scripts which you run to accomplish common systems administration tasks. `bolt` makes it easy to reuse those scripts without modification, and to run them quickly across a large number of nodes. Feel free to use an existing script of you have one in mind, if not we'll create a simple PowerShell script to test our connectivity to a known website.

Save the following as `testconnection.ps1`:

```powershell
Test-Connection -ComputerName "example.com" -Count 3 -Delay 2 -TTL 255 -BufferSize 256 -ThrottleLimit 32
```

Next we run the script using `bolt script run`. This will upload the script to all specified nodes, ensure it's executable and finally run it, returning the output to the console.

```
$ bolt script run testconnection.ps1 -n $WINNODE
Started on localhost...
Finished on localhost:
  STDOUT:

    Source        Destination     IPV4Address      IPV6Address                              Bytes    Time(ms)
    ------        -----------     -----------      -----------                              -----    --------
    Nano          example.com                                                               256      5
    Nano          example.com                                                               256      5
    Nano          example.com                                                               256      6


Ran on 1 node in 12.37 seconds
```

# Next steps

Now that you know how to run existing scripts with `bolt` you can move on to:

1. [Writing Tasks](../5-writing-tasks)
