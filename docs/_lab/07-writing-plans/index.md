---
title: Writing Plans
difficulty: Intermediate
time: Approximately 10 minutes
---

In this exercise you will discover Bolt Plans and how to run them with Bolt.

- [Write a Plan Using run_command](#write-a-plan-using-run_command)
- [Write a Plan Using run_task](#write-a-plan-using-run_task)

## Prerequisites
Complete the following before you start this lesson:

- [Installing Bolt](../01-installing-bolt)
- [Setting Up Test Nodes](../02-acquiring-nodes)
- [Running Commands](../03-running-commands)

## About Plans

Use plans when you want to run several commands together across multiple nodes. For instance to remove a node from a load balancer before you deploy the new version of the application, or to clear a cache after you re-index a search engine.

You can link a set of commands, scripts, and tasks together, and add parameters to them so they are easy to reuse. While you write plans in the Puppet language, you don't need to install Puppet to use them.

## Inspect Installed Plans

Bolt is packaged with useful modules and plan content. Run the `bolt plan show` command to view a list of the plans installed in the project directory.

```shell
bolt task show
```

The result:

```plain
aggregate::count
aggregate::nodes
canary
facts
facts::info
puppetdb_fact
reboot

MODULEPATH:
/project/Boltdir/modules:/project/Boltdir/site-modules:/project/Boltdir/site

Use bolt plan show <plan-name> to view details and parameters for a specific plan.
```


## Write a Plan Using run_command

Create a simple plan that runs a command on a list of nodes.

Save the following as `Boltdir/site-modules/exercise7/plans/command.pp`:

```puppet
{% include lesson1-10/Boltdir/site-modules/exercise7/plans/command.pp -%}
```

Run the plan:

```shell
bolt plan run exercise7::command nodes=node1
```

The result:

```plain
Starting: command 'uptime' on node1
Finished: command 'uptime' with 0 failures in 0.45 sec
Plan completed successfully with no result
```

> **Note:**
>
> * `nodes` is passed as a parameter like any other, rather than a flag. This makes plans flexible when it comes to taking lists of different types of nodes. You can still pass the names of groups in the inventory file to this parameter.
>
> * Use the `TargetSpec` type to denote nodes; it allows passing a single string describing a target URI or a comma-separated list of strings as supported by the `--nodes` argument to other commands. It also accepts an array of Targets, as resolved by calling the [`get_targets` method](https://puppet.com/docs/bolt/latest/writing_plans.html#calling-basic-plan-functions). You can iterate over Targets without needing to do your own string splitting, or as resolved from a group in an [inventory file](https://puppet.com/docs/bolt/latest/inventory_file.html).


## Write a Plan Using run_task
Create a task and then create a plan that uses the task.

Save the following task as `Boltdir/site-modules/exercise7/tasks/write.sh`. The task accepts a filename and some content and saves a file to `/tmp`.

```bash
{% include lesson1-10/Boltdir/site-modules/exercise7/tasks/write.sh -%}
```

Run the task directly with the following command:

```shell
bolt task run exercise7::write filename=hello content=world --nodes node1 --debug
```

In this case the task doesn't output anything to stdout. It can be useful to trace the running of the task, and for that the `--debug` flag is useful. Here is the output when run with debug:

```plain
Did not find config for node1 in inventory
Started with 100 max thread(s)
ModuleLoader: module 'boltlib' has unknown dependencies - it will have all other modules visible
Did not find config for node1 in inventory
Starting: task exercise7::write on node1
Authentication method 'gssapi-with-mic' is not available
Running task exercise7::write with '{"filename"=>"hello", "content"=>"world"}' via  on ["node1"]
Started on node1...
Running task run 'Task({'name' => 'exercise7::write', 'implementations' => [{'name' => 'write.sh', 'path' => '/Users/username/puppetlabs/tasks-hands-on-lab/07-writing-plans/modules/exercise7/tasks/write.sh', 'requirements' => []}], 'input_method' => undef})' on node1
Opened session
Executing: mktemp -d
stdout: /tmp/tmp.mJo9THENdL

Command returned successfully
Executing: chmod u\+x /tmp/tmp.mJo9THENdL/write.sh
Command returned successfully
Executing: PT_filename=hello PT_content=world /tmp/tmp.mJo9THENdL/write.sh
Command returned successfully
Executing: rm -rf /tmp/tmp.mJo9THENdL
Command returned successfully
Closed session
Finished on node1:
 {"node":"node1","status":"success","result":{"_output":""}}

  {
  }
Finished: task exercise7::write with 0 failures in 0.89 sec
Successful on 1 node: node1
Ran on 1 node in 0.97 seconds
```

Write a plan that uses the task you created. Save the following as `Boltdir/site-modules/exercise7/plans/writeread.pp`:

```puppet
{% include lesson1-10/Boltdir/site-modules/exercise7/plans/writeread.pp -%}
```

The plan takes three arguments, one of which (`content`) has a default value. We'll see shortly how Bolt uses that to validate user input. 

First, the plan runs the `exercise7::write` task from above, setting the arguments for the task to the values passed to the plan. This writes out a file in the `/tmp` directory. Next, the plan runs a command directly, in this case to output the content written to the file in the above task.

Run the plan using the following command:

```shell
bolt plan run exercise7::writeread filename=hello content=world nodes=node1
```

The result:

```plain
Starting: task exercise7::write on node1
Finished: task exercise7::write with 0 failures in 0.88 sec
Starting: command 'cat /tmp/hello' on node1
Finished: command 'cat /tmp/hello' with 0 failures in 0.41 sec
Plan completed successfully with no result
```


Since `content` is optional you can choose not to pass a value to it, in which case the default value will be assigned. Lastly, when running multiple steps in a plan only the last step will generate output.


## Next Steps

Now that you know how to create and run basic plans with Bolt you can move on to:

[Writing Advanced Tasks](../08-writing-advanced-tasks)
