## bolt

### NAME
`$ bolt` - Runs ad-hoc tasks on your nodes via ssh or winrm.

### SYNOPSIS
~~~
$ bolt task run <task-name> [<parameter>=<value> ...] [<target-pattern>] [--help, -h] [--format, -f <output-format>]
$ bolt plan run <plan-file> 
$ bolt command run '<command>'
$ bolt script run '<path>'
$ bolt file upload
$ bolt file download
~~~

##### Compare to PE CLI
~~~
$ puppet task run <task-name> [<parameter>=<value> ...] 
$ puppet task run exec command='<command>' 
~~~


### DESCRIPTION
`$ bolt` runs ad-hoc tasks, commands and scripts on your nodes via ssh or winrm. Use a plan to run multiple tasks in a particular order.

### GLOBAL OPTIONS

Option | Description
----------------------------- | --------------------------
--help <br>-h  | Show help page for bolt or for a specific task with <task-name>
--format <br>-f | Specify an output format. <br>Options: <br>`human`(default): interleaves stdout output from multiple nodes <br>`oneline`:provides one line summary for each node <br>`json`: 
--outputdir | Specify a directory to save output logs (1 file per node).
--shell | 'cmd' or 'powershell' when using winrm. 

### SELECT A TARGET

Option | Description
----------------------------- | --------------------------
--nodes <br>-n | Enter a list of nodes to run the task on. (Comma-separated. No quotes.) <br> `@<file-name>` Or provide a file with one nodename per line. 

### TASK OPTIONS

Option | Description
----------------------------- | --------------------------
--params <br>-p | Enter a string containing JSON parameters  <br> `@<file-name>` Or provide a file with JSON parameters. 


### OUTPUT



**View output per node while task/command/script is running on single or multiple nodes.**

**--human format (default)**

~~~
$ bolt [task/command/script] run [options...]
Starting [task/command/script]...
Nodes: 3

Started on node-1...
Started on node-2...
Started on node-3...
Finished on node-1
  status: restarted
  STDOUT:
    [stdout output...]
Finished on node-2
  status: restarted
  STDOUT:
    [stdout output...]
Finished on node-3
  status: restarted
  STDOUT:
    [stdout output...]
    
  

[Task/Command/Script] completed. 3/3 nodes succeeded.
Duration: 27 sec
~~~

- colors should match puppet job run output for started, finished, and errors.
- For tasks, capitalization of the finished node results comes from module (eg. status vs. Status).





**View output per node while task/command/script is running on single or multiple nodes.**

**--oneline format**

- stdout, stderr and messages from bolt are interleaved as they are output
- every line is prefixed with node name, timestamp, and `err`, `out`, or `msg` accordingly.
- nodename, timestamp and output type are space separated.
- timestamp format is HH:MM:SS


~~~
$ bolt [task/command/script] run [options...]
Starting [task/command/script]...            
Nodes: 3

node-1 HH:MM:SS msg started 
node-1 HH:MM:SS err [stderr output]
node-1 HH:MM:SS out [stdout output]
node-2 HH:MM:SS msg started
node-3 HH:MM:SS msg started
node-2 HH:MM:SS out [stdout output]
node-1 HH:MM:SS msg finished, succeeded
node-3 HH:MM:SS out [stdout output]
node-3 HH:MM:SS msg finished, failed
node-2 HH:MM:SS msg finished, succeeded


3 of 3 nodes completed. 2 of 3 nodes succeeded, 1 of 3 nodes failed.
Duration: [duration]

~~~



**View the response for each node when the node has finished (unstructured STDOUT):**
~~~
...

Finished on covfefe-2
  Status: completed
  STDOUT:
    Loaded plugins: fastestmirror
    Loading mirror speeds from cached hostfile
    * base: mirror.web-ster.com
    * extras: centos-distro.1gservers.com
    * updates: mirror.hmc.edu
    Resolving Dependencies
    --> Running transaction check
    ---> Package openssl.x86_64 1:1.0.1e-60.el7 will be a downgrade
    ---> Package openssl.x86_64 1:1.0.1e-60.el7_3.1 will be erased
    ---> Package openssl-libs.x86_64 1:1.0.1e-60.el7 will be a downgrade
    ---> Package openssl-libs.x86_64 1:1.0.1e-60.el7_3.1 will be erased
    --> Finished Dependency Resolution

    Dependencies Resolved

    ================================================================================
    Package              Arch           Version                 Repository    Size
    ================================================================================
    Downgrading:
    openssl              x86_64         1:1.0.1e-60.el7         base         713 k
    openssl-libs         x86_64         1:1.0.1e-60.el7         base         958 k

    Transaction Summary
    ================================================================================
    Downgrade  2 Packages

    Total download size: 1.6 M
    Downloading packages:
    --------------------------------------------------------------------------------
    Total                                              6.0 MB/s | 1.6 MB  00:00     
    Running transaction check
    Running transaction test
    Transaction test succeeded
    Running transaction
    Installing : 1:openssl-libs-1.0.1e-60.el7.x86_64                          1/4
    Installing : 1:openssl-1.0.1e-60.el7.x86_64                               2/4
    Cleanup    : 1:openssl-1.0.1e-60.el7_3.1.x86_64                           3/4
    Cleanup    : 1:openssl-libs-1.0.1e-60.el7_3.1.x86_64                      4/4
    Verifying  : 1:openssl-libs-1.0.1e-60.el7.x86_64                          1/4
    Verifying  : 1:openssl-1.0.1e-60.el7.x86_64                               2/4
    Verifying  : 1:openssl-1.0.1e-60.el7_3.1.x86_64                           3/4
    Verifying  : 1:openssl-libs-1.0.1e-60.el7_3.1.x86_64                      4/4

    Removed:
    openssl.x86_64 1:1.0.1e-60.el7_3.1   openssl-libs.x86_64 1:1.0.1e-60.el7_3.1  

    list:
    openssl.x86_64 1:1.0.1e-60.el7       openssl-libs.x86_64 1:1.0.1e-60.el7      

    Complete!
~~~

**View output per node while task plan is running.**
- TBD

