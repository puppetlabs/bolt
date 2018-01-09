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
plan exercise7::command(String $nodes) {
  $nodes_array = split($nodes, ',')
  run_command ("uptime",
    $nodes_array,
  )
}
```

We can run the plan like so:

```
$ bolt plan run exercise7::command nodes=$NODE --modulepath ./modules
ExecutionResult({'node1' => {'stdout' => " 23:08:34 up  2:02,  0 users,  load average: 0.00, 0.01, 0.05\n", 'stderr' => '', 'exit_code' => 0}})
```

Note that:

* `nodes` is passed as an argument like any other, rather than using a flag. This makes plans flexible when it comes to taking lists of different types of nodes for instance, or generating the list of nodes in code within the plan.


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
bolt task run exercise7::write filename=hello message=world --nodes=$NODE --modulepath ./modules --debug
```

Note that in this case the task doesn't output anything to stdout. It can be useful to still trace the running of the task, and for that the `--debug` flag is useful. Here is the output when run with debug:

```
2017-10-03T11:14:14.308961  ERROR 2acquiringnodes_ssh_1: could not connect to ssh-agent: Agent not configured
2017-10-03T11:14:14.322728  DEBUG 2acquiringnodes_ssh_1: Opened session
2017-10-03T11:14:14.322822  INFO 2acquiringnodes_ssh_1: Running task '/modules/exercise7/tasks/write.sh'
2017-10-03T11:14:14.322873  DEBUG 2acquiringnodes_ssh_1: arguments: {"filename"=>"hello", "message"=>"world"}
input_method: both
2017-10-03T11:14:14.331550  DEBUG 2acquiringnodes_ssh_1: Uploading /modules/exercise7/tasks/write.sh to /tmp/tmp.TJe5oOFIFa/write.sh
2017-10-03T11:14:14.382893  DEBUG 2acquiringnodes_ssh_1: Executing: chmod u+x '/tmp/tmp.TJe5oOFIFa/write.sh'
2017-10-03T11:14:14.386333  DEBUG 2acquiringnodes_ssh_1: Command returned successfully
2017-10-03T11:14:14.386388  DEBUG 2acquiringnodes_ssh_1: Executing: export PT_filename='hello' PT_message='world' && '/tmp/tmp.TJe5oOFIFa/write.sh'
2017-10-03T11:14:14.436844  DEBUG 2acquiringnodes_ssh_1: Command returned successfully
2017-10-03T11:14:14.436880  DEBUG 2acquiringnodes_ssh_1: Executing: rm -f '/tmp/tmp.TJe5oOFIFa/write.sh'
2017-10-03T11:14:14.496337  DEBUG 2acquiringnodes_ssh_1: Command returned successfully
2017-10-03T11:14:14.496382  DEBUG 2acquiringnodes_ssh_1: Executing: rmdir '/tmp/tmp.TJe5oOFIFa'

2017-10-03T11:14:14.552774  DEBUG 2acquiringnodes_ssh_1: Command returned successfully
2017-10-03T11:14:14.596419  DEBUG 2acquiringnodes_ssh_1: Closed session
2acquiringnodes_ssh_1:


Ran on 1 node in 0.39 seconds
```

Now lets write a plan that uses our task. Save the following as `modules/exercise7/plans/writeread.pp`:

```puppet
plan exercise7::writeread(
  String $nodes,
  String $filename,
  String $message = 'Hello',
) {
  $nodes_array = split($nodes, ',')
  run_task("exercise7::write",
    $nodes_array,
    filename => $filename,
    message  => $message,
  )
  run_command("cat /tmp/${filename}", $nodes_array)
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

Plans should be used whenever you want to run several commands together, often based on the output of previous commands and across multiple nodes. For instance removing a node from a load balancer before deploying the new version of the application, or clearing a cache after reindexing a search engine.

# Next steps

Now you know how to download and run third party tasks with `bolt` you can move on to:

1. [Writing advanced Tasks](../8-writing-advanced-tasks)
