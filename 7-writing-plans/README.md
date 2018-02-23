# Writing Plans

> **Difficulty**: Intermediate

> **Time**: Approximately 10 minutes

In this exercise you will discover Puppet Plans and how to run them with `bolt`.

- [Write a plan using run_command](#write-a-plan-using-run_command)
- [Write a plan using run_task](#write-a-plan-using-run_task)

# Prerequisites

For the following exercises you should already have `bolt` installed and have a few nodes (either Windows or Linux) available to run commands against. The following guides will help:

1. [Installing Bolt](../1-installing-bolt)
1. [Acquiring nodes](../2-acquiring-nodes)

It is also useful to have some familiarity with running commands with `bolt` so you understand passing nodes and credentials. The following exercise is recommended:

1. [Running Commands](../3-running-commands)

# Write a plan using run_command

Plans allow for linking a set of commands, scripts and tasks together; and to parameterize them so they are easy to reuse. Plans are written using the Puppet language but you don't need to install Puppet separately to use them.

Let's create a simple plan which takes a list of nodes and runs a command on them. Save the following as `modules/exercise7/plans/command.pp`:

```puppet
plan exercise7::command (TargetSpec $nodes) {
  run_command("uptime", $nodes)
}
```

We can run the plan like so:

```
$ bolt plan run exercise7::command nodes=all --modulepath ./modules
2018-02-16T15:35:47.843668 INFO   Bolt::Executor: Starting command run 'uptime' on ["node1"]
2018-02-16T15:35:48.154690 INFO   Bolt::Executor: Ran command 'uptime' on 1 node with 0 failures
[
  {
    "node": "node1",
    "status": "success",
    "result": {
      "stdout": " 23:35:48 up 2 min,  0 users,  load average: 0.10, 0.09, 0.04\n",
      "stderr": "",
      "exit_code": 0
    }
  }
]
```

Note that:

* `nodes` is passed as an argument like any other, rather than using a flag. This makes plans flexible when it comes to taking lists of different types of nodes for instance, or generating the list of nodes in code within the plan.

    As a convention, we recommend using the `TargetSpec` type to denote nodes; it allows passing a single string describing a target URI or a comma-separated list of strings as supported by the `--nodes` argument to other commands. It also accepts an array of Targets, as resolved by calling the [`get_targets` method](https://puppet.com/docs/bolt/0.x/writing_plans.html#calling-basic-plan-functions), allowing you to iterate over Targets without needing to do your own string splitting, or as resolved from a group in an [inventory file](https://puppet.com/docs/bolt/0.x/inventory_file.html).


# Write a plan using run_task

The above example is obviously very simple. It simply wraps a command in a plan. But plans can run more than one command, and can also run scripts and tasks too. Lets look at a more involved example.

Save the following task as `modules/exercise7/tasks/write.sh`:

```bash
#!/bin/sh

if [ -z "$PT_message" ]; then
  echo "Need to pass a message"
  exit 1
fi

if [ -z "$PT_filename" ]; then
  echo "Need to pass a filename"
  exit 1
fi

echo $PT_message > "/tmp/${PT_filename}"
```

This task simply accepts a filename and some content and saves a file to `/tmp`.

You can run the task directly with the following command:

```
bolt task run exercise7::write filename=hello message=world --nodes=all --modulepath ./modules --debug
```

Note that in this case the task doesn't output anything to stdout. It can be useful to still trace the running of the task, and for that the `--debug` flag is useful. Here is the output when run with debug:

```
2018-02-16T15:36:31.643418 DEBUG  Bolt::Inventory: Did not find node1 in inventory
2018-02-16T15:36:32.713360 DEBUG  Bolt::Executor: Started with 100 max thread(s)
2018-02-16T15:36:32.932771 DEBUG  Bolt::Inventory: Did not find node1 in inventory
2018-02-16T15:36:32.932869 INFO   Bolt::Executor: Starting task exercise7::write on ["node1"]
2018-02-16T15:36:32.932892 DEBUG  Bolt::Executor: Arguments: {"filename"=>"hello", "message"=>"world"} Input method: both
2018-02-16T15:36:33.178433 DEBUG  Bolt::Transport::SSH: Authentication method 'gssapi-with-mic' is not available
2018-02-16T15:36:33.179532 DEBUG  Bolt::Transport::SSH: Running task run 'Task({'name' => 'exercise7::write', 'executable' => '/Users/michaelsmith/puppetlabs/tasks-hands-on-lab/7-writing-plans/modules/exercise7/tasks/write.sh'})' on node1
Started on node1...
2018-02-16T15:36:33.216451 DEBUG  node1: Opened session
2018-02-16T15:36:33.216604 DEBUG  node1: Executing: mktemp -d
2018-02-16T15:36:33.395440 DEBUG  node1: stdout: /tmp/tmp.I7ZTz4OmfY

2018-02-16T15:36:33.395746 DEBUG  node1: Command returned successfully
2018-02-16T15:36:33.411634 DEBUG  node1: Executing: chmod u+x '/tmp/tmp.I7ZTz4OmfY/write.sh'
2018-02-16T15:36:33.423831 DEBUG  node1: Command returned successfully
2018-02-16T15:36:33.424137 DEBUG  node1: Executing: PT_filename='hello' PT_message='world' '/tmp/tmp.I7ZTz4OmfY/write.sh'
2018-02-16T15:36:33.436180 DEBUG  node1: Command returned successfully
2018-02-16T15:36:33.436226 DEBUG  node1: Executing: rm -rf '/tmp/tmp.I7ZTz4OmfY'
2018-02-16T15:36:33.447658 DEBUG  node1: Command returned successfully
2018-02-16T15:36:33.447850 DEBUG  node1: Closed session
2018-02-16T15:36:33.447918 DEBUG  Bolt::Transport::SSH: Result on node1: {"_output":""}
Finished on node1:

  {
  }
2018-02-16T15:36:33.448381 INFO   Bolt::Executor: Ran task 'exercise7::write' on 1 node with 0 failures
Ran on 1 node in 0.74 seconds
```

Now lets write a plan that uses our task. Save the following as `modules/exercise7/plans/writeread.pp`:

```puppet
plan exercise7::writeread (
  TargetSpec $nodes,
  String     $filename,
  String     $message = 'Hello',
) {
  run_task(
    'exercise7::write',
    $nodes,
    filename => $filename,
    message  => $message,
  )
  run_command("cat /tmp/${filename}", $nodes)
}
```

Note that:

* The plan takes three arguments, one of which (`message`) has a default value. We'll see shortly how `bolt` uses that to validate user input.
* We use the Puppet `split` function to support passing a comma-separated list of nodes. Plans are just Puppet, so you can use any of the available [functions](https://docs.puppet.com/puppet/latest/function.html) or [native data types](https://docs.puppet.com/puppet/latest/lang_data_type.html).
* First we run our `exercise7::write` task from above, setting the arguments for the task to the values passed to the plan. This writes out a file in the `/tmp` directory.
* We then run a command directly from the plan, in this case to output the content we just wrote to the file in the above task.

You can run the plan using the following command:

```
bolt plan run exercise7::writeread filename=hello message=world nodes=<nodes> --modulepath ./modules
```

Note:

* `message` is optional. If it's not passed it will use the default value from the plan.
* When running multiple steps in a plan only the last step will generate output

Plans should be used whenever you want to run several commands together, often based on the output of previous commands and across multiple nodes. For instance removing a node from a load balancer before deploying the new version of the application, or clearing a cache after re-indexing a search engine.

# Next steps

Now that you know how to download and run third party tasks with `bolt` you can move on to:

1. [Writing advanced Tasks](../8-writing-advanced-tasks)
