## bolt

### NAME
`$ bolt` - Runs ad-hoc tasks on your hosts via ssh or winrm.

### SYNOPSIS
~~~
$ bolt run <task-name> [<parameter>=<value> ...] [<target-pattern>] [--help, -h] [--format, -f <output-format>]
$ bolt exec command='<command>' [<target-pattern>]
$ bolt exec script='<path>' [<target-pattern>]
~~~

### DESCRIPTION
`$ bolt` runs ad-hoc tasks on your hosts via ssh or winrm. Restart a service with the service task, run a script with 'exec script', or issue a command with 'exec command'.   

### OPTIONS

Option | Description
----------------------------- | --------------------------
--format <br>-f | Specify an output format. (Options: TBD)
--help <br>-h  | Show help page for bolt or for a specific task with <task-name>
--shell | 'cmd' or 'powershell' when using winrm. We might have similar configuration for ssh transports.

### SELECT A TARGET

Option | Description
----------------------------- | --------------------------
--hosts <br>-h | Enter a list of hosts to run the task on. (Comma-separated or space-separated so that you can do --hosts europa-{1,9}, and allow the shell to expand the host names. No quotes.) <br> Or provide a file with one hostname per line.



### EXAMPLES

**Query a host for the number of SSL connections it’s handling**:
~~~
$ bolt exec —nodes europa command=‘netstat -an | grep “:443.*ESTABLISHED” | wc -1’
europa-1: 350

~~~
- This runs the "exec" task. 
- The `--nodes` argument is for bolt itself. 
- The `command` argument is the name of a parameter to the task, and the netstat command is what to run on the remote host.




**Execute "facter" on multiple systems**:
This demonstrates how a command can be run on multiple systems, and how the results are displayed:
~~~
$ bolt exec command='facter osfamily' --hosts europa-1, europa-2
europa-2: Redhat
europa-1: Redhat

~~~
- Host names are comma-separated, or space separated so that you can do --hosts europa-{1,9}, and allow the shell to expand the node names. 
- we need a way of easily passing multiple hosts, something like:
~~~
$ bolt exec command='facter ipaddress' --hosts <hosts.txt>
~~~
Passing one hostname per line works for a homogeneous environment, e.g. all *nix. But what about trying to execute a single command across *nix and Windows, like "facter whereami"? To support that the protocol/scheme probably needs to be specified per-host (optionally):

ssh://rhel.ops.foo
ssh://rhel.ops.foo:222
winrm://win.ops.foo
rhel2.ops.foo

It could also support alternate ports, e.g. ssh://rhel.ops.foo:2222.
