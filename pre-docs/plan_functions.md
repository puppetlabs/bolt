# Plan execution functions

Your plan can execute multiple functions on remote systems.

Your plan can include functions to run commands, scripts, tasks, and other plans on remote nodes. These execution functions correspond to task runner commands.

**Note:** All the $nodes arguments support the patterns supported by --nodes \(except for shell expansion\).

## Bolt functions

### add\_facts

Deep merges a hash of facts with the existing facts on a target.

```
add_facts(Target $target, Hash $facts)
```

 *Returns:* `Hash[String, Data]` The target's new facts.

-    **target** `Target` A target.
-    **facts** `Hash` A hash of fact names to values that may include structured facts.

 **Example:** Adding facts to a target

```
add_facts($target, { 'os' => { 'family' => 'windows', 'name' => 'windows' } })
```

### facts

Returns the facts hash for a target.

```
facts(Target $target)
```

 *Returns:* `Hash[String, Data]` The target's facts.

-    **target** `Target` A target.

 **Example:** Getting facts

```
facts($target)
```

### fail\_plan

Raises a Bolt::PlanFailure exception to signal to callers that the plan failed.

Plan authors should call this function when their plan is not successful. The error may then be caught by another plans run\_plan function or in bolt itself

#### Fail a plan, generating an exception from the parameters.

```
fail_plan(String[1] $msg, Optional[String[1]] $kind, Optional[Hash[String[1], Any]] $details, Optional[String[1]] $issue_code)
```

 *Returns:* `Any` Raises an exception.

-    **msg** `String[1]` An error message.
-    **kind** `Optional[String[1]]` An easily matchable error kind.
-    **details** `Optional[Hash[String[1], Any]]` Machine-parseable details about the error.
-    **issue\_code** `Optional[String[1]]` Unused.

 **Example:** Raise an exception

```
fail_plan('We goofed up', 'task-unexpected-result', { 'result' => 'null' })
```

#### Fail a plan, generating an exception from an existing Error object.

```
fail_plan(Error $error)
```

 *Returns:* `Any` Raises an exception.

-    **error** `Error` An error object.

 **Example:** Raise an exception

```
fail_plan(Error('We goofed up', 'task-unexpected-result', { 'result' => 'null' }))
```

### file\_upload

Uploads the given file or directory to the given set of targets and returns the result from each upload. This function does nothing if the list of targets is empty.

#### Upload a file.

```
<<<<<<< HEAD
file_upload(String[1] $source, String[1] $destination, Boltlib::TargetSpec $targets, Optional[Hash[String[1], Any]] $options)
=======
upload_file(String[1] $source, String[1] $destination, Boltlib::TargetSpec $targets, Optional[Hash[String[1], Any]] $options)
>>>>>>> upstream/master
```

 *Returns:* `ResultSet` A list of results, one entry per target.

-    **source** `String[1]` A source path, either an absolute path or a modulename/filename selector for a file in <moduleroot\>/files.
-    **destination** `String[1]` An absolute path on the target\(s\).
-    **targets** `Boltlib::TargetSpec` A pattern identifying zero or more targets. See [ `get_targets` ](plan_functions.md#) for accepted patterns.
-    **options** `Optional[Hash[String[1], Any]]` Additional options: '\_catch\_errors', '\_run\_as'.

 **Example:** Upload a local file to Linux targets and change owner to 'root'

```
<<<<<<< HEAD
file_upload('/var/tmp/payload.tgz', '/tmp/payload.tgz', $targets, '_run_as' => 'root')
=======
upload_file('/var/tmp/payload.tgz', '/tmp/payload.tgz', $targets, '_run_as' => 'root')
>>>>>>> upstream/master
```

 **Example:** Upload a module file to a Windows target

```
<<<<<<< HEAD
file_upload('postgres/default.conf', 'C:/ProgramData/postgres/default.conf', $target)
=======
upload_file('postgres/default.conf', 'C:/ProgramData/postgres/default.conf', $target)
>>>>>>> upstream/master
```

#### Upload a file, logging the provided description.

```
<<<<<<< HEAD
file_upload(String[1] $source, String[1] $destination, Boltlib::TargetSpec $targets, String $description, Optional[Hash[String[1], Any]] $options)
=======
upload_file(String[1] $source, String[1] $destination, Boltlib::TargetSpec $targets, String $description, Optional[Hash[String[1], Any]] $options)
>>>>>>> upstream/master
```

 *Returns:* `ResultSet` A list of results, one entry per target.

-    **source** `String[1]` A source path, either an absolute path or a modulename/filename selector for a file in <moduleroot\>/files.
-    **destination** `String[1]` An absolute path on the target\(s\).
-    **targets** `Boltlib::TargetSpec` A pattern identifying zero or more targets. See [ `get_targets` ](plan_functions.md#) for accepted patterns.
-    **description** `String` A description to be output when calling this function.
-    **options** `Optional[Hash[String[1], Any]]` Additional options: '\_catch\_errors', '\_run\_as'.

 **Example:** Upload a file

```
<<<<<<< HEAD
file_upload('/var/tmp/payload.tgz', '/tmp/payload.tgz', $targets, 'Uploading payload to unpack')
=======
upload_file('/var/tmp/payload.tgz', '/tmp/payload.tgz', $targets, 'Uploading payload to unpack')
>>>>>>> upstream/master
```

### get\_targets

Parses common ways of referring to targets and returns an array of Targets.

```
get_targets(Boltlib::TargetSpec $names)
```

 *Returns:* `Array[Target]` A list of unique Targets resolved from any target URIs and groups.

-    **names** `Boltlib::TargetSpec` A pattern or array of patterns identifying a set of targets.

 **Example:** Resolve a group

```
get_targets('group1')
```

 **Example:** Resolve a target URI

```
get_targets('winrm://host2:54321')
```

 **Example:** Resolve array of groups and/or target URIs

```
get_targets(['host1', 'group1', 'winrm://host2:54321'])
```

 **Example:** Resolve string consisting of a comma-separated list of groups and/or target URIs

```
get_targets('host1,group1,winrm://host2:54321')
```

 **Example:** Run on localhost

```
get_targets('localhost')
```

### puppetdb\_fact

Collects facts based on a list of certnames.

-   If a node is not found in PuppetDB, it's included in the returned hash with empty facts hash.
-   Otherwise the node is included in the hash with a value that is a hash of it's facts.

```
puppetdb_fact(Array[String] $certnames)
```

 *Returns:* `Hash[String, Data]` A hash of certname to facts hash for each matched Target.

-    **certnames** `Array[String]` Array of certnames.

 **Example:** Get facts for nodes

```
puppetdb_fact(['app.example.com', 'db.example.com'])
```

### puppetdb\_query

Makes a query to puppetdb using Bolt's PuppetDB client.

```
puppetdb_query(Variant[String, Array[Data]] $query)
```

 *Returns:* `Array[Data]` Results of the PuppetDB query.

-    **query** `Variant[String, Array[Data]]` A PQL query.

 **Example:** Request certnames for all nodes

```
puppetdb_query('nodes[certname] {}')
```

### run\_command

Runs a command on the given set of targets and returns the result from each command execution. This function does nothing if the list of targets is empty.

#### Run a command.

```
run_command(String[1] $command, Boltlib::TargetSpec $targets, Optional[Hash[String[1], Any]] $options)
```

 *Returns:* `ResultSet` A list of results, one entry per target.

-    **command** `String[1]` A command to run on target.
-    **targets** `Boltlib::TargetSpec` A pattern identifying zero or more targets. See [ `get_targets` ](plan_functions.md#) for accepted patterns.
-    **options** `Optional[Hash[String[1], Any]]` Additional options: '\_catch\_errors', '\_run\_as'.

 **Example:** Run a command on targets

```
run_command('hostname', $targets, '_catch_errors' => true)
```

#### Run a command, logging the provided description.

```
run_command(String[1] $command, Boltlib::TargetSpec $targets, String $description, Optional[Hash[String[1], Any]] $options)
```

 *Returns:* `ResultSet` A list of results, one entry per target.

-    **command** `String[1]` A command to run on target.
-    **targets** `Boltlib::TargetSpec` A pattern identifying zero or more targets. See [ `get_targets` ](plan_functions.md#) for accepted patterns.
-    **description** `String` A description to be output when calling this function.
-    **options** `Optional[Hash[String[1], Any]]` Additional options: '\_catch\_errors', '\_run\_as'.

 **Example:** Run a command on targets

```
run_command('hostname', $targets, '_catch_errors' => true)
```

### run\_plan

Runs the `plan` referenced by its name. A plan is autoloaded from `<moduleroot>/plans`.

```
run_plan(String $plan_name, Optional[Hash] $named_args)
```

 *Returns:* `PlanResult` The result of running the plan. Undef if plan does not explicitly return results.

-    **plan\_name** `String` The plan to run.
-    **named\_args** `Optional[Hash]` Arguments to the plan. Can also include additional options: '\_catch\_errors', '\_run\_as'.

 **Example:** Run a plan

```
run_plan('canary', 'command' => 'false', 'nodes' => $targets, '_catch_errors' => true)
```

### run\_script

Uploads the given script to the given set of targets and returns the result of having each target execute the script. This function does nothing if the list of targets is empty.

#### Run a script.

```
run_script(String[1] $script, Boltlib::TargetSpec $targets, Optional[Hash[String[1], Any]] $options)
```

 *Returns:* `ResultSet` A list of results, one entry per target.

-    **script** `String[1]` Path to a script to run on target. May be an absolute path or a modulename/filename selector for a file in <moduleroot\>/files.
-    **targets** `Boltlib::TargetSpec` A pattern identifying zero or more targets. See [ `get_targets` ](plan_functions.md#) for accepted patterns.
-    **options** `Optional[Hash[String[1], Any]]` Specify an array of arguments to the 'arguments' key to be passed to the script. Additional options: '\_catch\_errors', '\_run\_as'.

 **Example:** Run a local script on Linux targets as 'root'

```
run_script('/var/tmp/myscript', $targets, '_run_as' => 'root')
```

 **Example:** Run a module-provided script with arguments

```
<<<<<<< HEAD
file_upload('iis/setup.ps1', $target, 'arguments' => ['/u', 'Administrator'])
=======
run_script('iis/setup.ps1', $target, 'arguments' => ['/u', 'Administrator'])
>>>>>>> upstream/master
```

#### Run a script, logging the provided description.

```
run_script(String[1] $script, Boltlib::TargetSpec $targets, String $description, Optional[Hash[String[1], Any]] $options)
```

 *Returns:* `ResultSet` A list of results, one entry per target.

-    **script** `String[1]` Path to a script to run on target. May be an absolute path or a modulename/filename selector for a file in <moduleroot\>/files.
-    **targets** `Boltlib::TargetSpec` A pattern identifying zero or more targets. See [ `get_targets` ](plan_functions.md#) for accepted patterns.
-    **description** `String` A description to be output when calling this function.
-    **options** `Optional[Hash[String[1], Any]]` Specify an array of arguments to the 'arguments' key to be passed to the script. Additional options: '\_catch\_errors', '\_run\_as'.

 **Example:** Run a script

```
<<<<<<< HEAD
file_upload('/var/tmp/myscript', $targets, 'Downloading my application')
=======
run_script('/var/tmp/myscript', $targets, 'Downloading my application')
>>>>>>> upstream/master
```

### run\_task

Runs a given instance of a `Task` on the given set of targets and returns the result from each. This function does nothing if the list of targets is empty.

#### Run a task.

```
run_task(String[1] $task_name, Boltlib::TargetSpec $targets, Optional[Hash[String[1], Any]] $task_args)
```

 *Returns:* `ResultSet` A list of results, one entry per target.

-    **task\_name** `String[1]` The task to run.
-    **targets** `Boltlib::TargetSpec` A pattern identifying zero or more targets. See [ `get_targets` ](plan_functions.md#) for accepted patterns.
-    **task\_args** `Optional[Hash[String[1], Any]]` Arguments to the plan. Can also include additional options: '\_catch\_errors', '\_run\_as'.

 **Example:** Run a task as root

```
run_task('facts', $targets, '_run_as' => 'root')
```

#### Run a task, logging the provided description.

```
run_task(String[1] $task_name, Boltlib::TargetSpec $targets, String $description, Optional[Hash[String[1], Any]] $task_args)
```

 *Returns:* `ResultSet` A list of results, one entry per target.

-    **task\_name** `String[1]` The task to run.
-    **targets** `Boltlib::TargetSpec` A pattern identifying zero or more targets. See [ `get_targets` ](plan_functions.md#) for accepted patterns.
-    **description** `String` A description to be output when calling this function.
-    **task\_args** `Optional[Hash[String[1], Any]]` Arguments to the plan. Can also include additional options: '\_catch\_errors', '\_run\_as'.

 **Example:** Run a task

```
run_task('facts', $targets, 'Gather OS facts')
```

#### Run a task, calling the block as each node starts and finishes execution. This is used from 'bolt task run'

```
run_task(String[1] $task_name, Boltlib::TargetSpec $targets, Optional[String] $description, Optional[Hash[String[1], Any]] $task_args, Callable[Struct[{type => Enum[node_start, node_result], target => Target}], 1, 1] &$block)
```

 *Returns:* `ResultSet` A list of results, one entry per target.

-    **task\_name** `String[1]` The task to run.
-    **targets** `Boltlib::TargetSpec` A pattern identifying zero or more targets. See [ `get_targets` ](plan_functions.md#) for accepted patterns.
-    **description** `Optional[String]` A description to be output when calling this function.
-    **task\_args** `Optional[Hash[String[1], Any]]` Arguments to the plan. Can also include additional options: '\_catch\_errors', '\_run\_as'.
-    **&block** `Callable[Struct[{type => Enum[node_start, node_result], target => Target}], 1, 1]` A block that's invoked as actions are started and finished on each node.

### set\_feature

Sets a particular feature to present on a target.

Features are used to determine what implementation of a task should be run. Currently supported features are - powershell - shell - puppet-agent

```
set_feature(Target $target, String $feature, Optional[Boolean] $value)
```

 *Returns:* `Undef` 

-    **target** `Target` The Target object to add features to. See [ `get_targets` ](plan_functions.md#).
-    **feature** `String` The string identifying the feature.
-    **value** `Optional[Boolean]` Whether the feature is supported.

 **Example:** Add the puppet-agent feature to a target

```
set_feature($target, 'puppet-agent', true)
```

### set\_var

Sets a variable \{ key =\> value \} for a target.

```
set_var(Target $target, String $key, Data $value)
```

 *Returns:* `Undef` 

-    **target** `Target` The Target object to set the variable for. See [ `get_targets` ](plan_functions.md#).
-    **key** `String` The key for the variable.
-    **value** `Data` The value of the variable.

 **Example:** Set a variable on a target

```
$target.set_var('ephemeral', true)
```

### vars

Returns a hash of the 'vars' \(variables\) assigned to a target.

Vars can be assigned through the inventory file or `set_var` function. Plan authors can call this function on a target to get the variable hash for that target.

```
vars(Target $target)
```

 *Returns:* `Hash[String, Data]` A hash of the 'vars' \(variables\) assigned to a target.

-    **target** `Target` The Target object to get variables from. See [ `get_targets` ](plan_functions.md#).

 **Example:** Get vars for a target

```
$target.vars
```

### without\_default\_logging

Define a block where default logging is suppressed.

Messages for actions within this block will be logged at `info` level instead of `notice`, so they will not be seen normally but \# will still be present when `verbose` logging is requested.

```
without_default_logging(Callable[0, 0] &$block)
```

 *Returns:* `Undef` 

-    **&block** `Callable[0, 0]` The block where action logging is suppressed.

 **Example:** Suppress default logging for a series of functions

```
without_default_logging() || {
  notice("Deploying on ${nodes}")
  get_targets($nodes).each |$node| {
    run_task(deploy, $node)
  }
}
```

