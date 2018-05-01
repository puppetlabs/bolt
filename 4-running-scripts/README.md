# Running Scripts

> **Difficulty**: Basic

> **Time**: Approximately 5 minutes

In this exercise you will run existing scripts against remote nodes using Bolt.

- [Test Linux nodes for ShellShock](#test-linux-nodes-for-shellshock)
- [Test Windows external connectivity](#test-windows-external-connectivity)

# Prerequisites
Complete the following before you start this lesson:

1. [Installing Bolt](../1-installing-bolt)
1. [Setting up test nodes](../2-acquiring-nodes)
1. [Running Commands](../3-running-commands)

# Test Linux nodes for ShellShock
Run the [bashcheck](https://github.com/hannob/bashcheck) script to check on ShellShock and related vulnerabilities.

**Tip:** You likely already have a set of scripts that you run to accomplish common systems administration tasks. Bolt makes it easy to reuse your scripts without modification and to run them quickly across a large number of nodes. Feel free to replace the bashcheck script in this exercise with one of your own. Just set the shebang line correctly and you can run scripts in Python, Ruby, Perl or another scripting language.


1. Download `bashcheck` using `curl`, 'wget',  or similar:

    ```
    curl -O https://raw.githubusercontent.com/hannob/bashcheck/master/bashcheck
    ```

2. Run the script using the command `bolt script run <script-name> <script options>`. This uploads the script to the nodes you have specified. 

    ```
    bolt script run bashcheck --nodes all
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
    Ran on 1 node in 0.41 seconds
    ```



# Test Windows external connectivity
Create a simple PowerShell script to test connectivity to a known website.

**Tip:** You likely already have a set of scripts that you run to accomplish common systems administration tasks. Bolt makes it easy to reuse your scripts without modification and to run them quickly across a large number of nodes. Feel free to replace the script in this exercise with one of your own.

1. Save the following as `testconnection.ps1`:

    ```powershell
    Test-Connection -ComputerName "example.com" -Count 3 -Delay 2 -TTL 255 -BufferSize 256 -ThrottleLimit 32
    ```

2. Run the script using the command `bolt script run <script-name> <script options>`. This uploads the script to the nodes you have specified, ensures its executable, runs it, and returns output to the console.

    ```
    bolt script run testconnection.ps1 -n $WINNODE
    ```
    The result:
    ```    
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

Now that you know how to use Bolt to run existing scripts you can move on to:

[Writing Tasks](../5-writing-tasks)
