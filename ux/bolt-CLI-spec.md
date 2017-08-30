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


### EXAMPLES


**Query a node for the number of SSL connections it’s handling**:
~~~
$ bolt command run ‘netstat -an | grep “:443.*ESTABLISHED” | wc -1’ --nodes europa
europa-1: 350

~~~



**Execute "facter" on multiple systems**:
This demonstrates how a command can be run on multiple systems, and how the results are displayed:
~~~
$ bolt command run 'facter osfamily' --nodes europa-1,europa-2
europa-2: Redhat
europa-1: Redhat
~~~




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
