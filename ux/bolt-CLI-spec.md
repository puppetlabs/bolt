## bolt

### NAME
`$ bolt` - Runs ad-hoc tasks on your nodes via ssh or winrm.

### SYNOPSIS
~~~
$ bolt run <task-name> [<parameter>=<value> ...] [<target-pattern>] [--help, -h] [--format, -f <output-format>]
$ bolt exec command='<command>' [<target-pattern>]
$ bolt exec script='<path>' [<target-pattern>]
~~~

### DESCRIPTION
`$ bolt` runs ad-hoc tasks on your nodes via ssh or winrm. Restart a service with the service task, run a script with 'exec script', or issue a command with 'exec command'.   

### OPTIONS

Option | Description
----------------------------- | --------------------------
--format <br>-f | Specify an output format. (Options: TBD)
--help <br>-h  | Show help page for bolt or for a specific task with <task-name>
--shell | 'cmd' or 'powershell' when using winrm. We might have similar configuration for ssh transports.

### SELECT A TARGET

Option | Description
----------------------------- | --------------------------
--nodes <br>-n | Enter a list of nodes to run the task on. (Comma-separated or space-separated so that you can do --nodes europa-{1,9}, and allow the shell to expand the node names. No quotes.) <br> Or provide a file with one nodename per line.



### EXAMPLES


**Query a node for the number of SSL connections it’s handling**:
~~~
$ bolt exec command=‘netstat -an | grep “:443.*ESTABLISHED” | wc -1’ --nodes europa
europa-1: 350

~~~
- This runs the "exec" task. 
- The `--nodes` argument is for bolt itself. 
- The `command` argument is the name of a parameter to the task, and the netstat command is what to run on the remote node.




**Execute "facter" on multiple systems**:
This demonstrates how a command can be run on multiple systems, and how the results are displayed:
~~~
$ bolt exec command='facter osfamily' --nodes europa-1, europa-2
europa-2: Redhat
europa-1: Redhat

~~~
- Node names are comma-separated, or space separated so that you can do --nodes europa-{1,9}, and allow the shell to expand the node names. 
- we need a way of easily passing multiple nodes, something like:
~~~
$ bolt exec command='facter ipaddress' --nodes <nodes.txt>
~~~
Passing one nodename per line works for a homogeneous environment, e.g. all *nix. But what about trying to execute a single command across *nix and Windows, like "facter whereami"? To support that the protocol/scheme probably needs to be specified per-node (optionally):

ssh://rhel.ops.foo
ssh://rhel.ops.foo:222
winrm://win.ops.foo
rhel2.ops.foo

It could also support alternate ports, e.g. ssh://rhel.ops.foo:2222.


--- 
Placeholders for examples:

**Run a single command**

**Run a shell script**

**Transfer files**

**Install puppet**

**Run puppet resource**

**Run a Puppet task**

**Run a Puppet task plan**

**Forage for discovery info**


**Output**

**View output per node while task is running.**
- Logs or streaming?

**View task progress (failures) while task is running.**

**View the response for each node when the node has finished.**
- Save logs per node, not streaming output.

**Stop a task while it is running.**
- Stopping a task would continue in-progress runs, but skip anything that hasn't started yet.
