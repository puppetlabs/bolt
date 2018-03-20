# Writing advanced Plans

> **Difficulty**: Intermediate

> **Time**: Approximately 10 minutes

In this exercise you will further explore Puppet Plans:

- [Write a plan which uses input and output](#write-a-plan-which-uses-input-and-output)
- [Write a plan which handles errors](#write-a-plan-which-handles-errors)

# Prerequisites

For the following exercises you should already have `bolt` installed and have a few nodes (either Windows or Linux) available to run commands against. The following guides will help:

1. [Installing Bolt](../1-installing-bolt)
1. [Acquiring nodes](../2-acquiring-nodes)

It is also useful to have some familiarity with writing and running Plans with `bolt`. The following exercise is recommended:

1. [Running Commands](../7-writing-plans)

# Write a plan which uses input and output

In the previous exercise we ran tasks and commands within the context of a plan, but we didn't capture the return values or use those values in subsequent steps. The ability to use the output of a task as the input to another task allows for creating much more complex and powerful plans.

First let's create a task. This will print a JSON structure with an `answer` key with a value of true or false. The important thing to note is the use of JSON to structure our return value. Save the following as `modules/exercise9/tasks/yesorno.py`:

```python
#!/usr/bin/env python

"""
This script returns a JSON string with a single key, answer which
has a boolean value. It should flip between returning true and false
at random
"""

import json
import random

print(json.dumps({'answer': bool(random.getrandbits(1))}))
```

Then we can write out the plan. Save the following as `modules/exercise9/plans/yesorno.pp`:

```puppet
plan exercise9::yesorno (TargetSpec $nodes) {
  $results = run_task('exercise9::yesorno', $nodes)
  $subset = $results.filter |$result| { $result[answer] == true }.map |$result| { $result.target }
  run_command("uptime", $subset)
}
```

In the above plan we:

* Accept a comma-separated list of nodes
* Run the `exercise9::yesorno` task from above on all of our nodes
* Store the results of running the task in the variable `$results`. This will contain a `ResultSet` containing a list of `Result` objects for each node and the data parsed from the JSON response from the task
* We filter the list of results to get the node names for only those that answered `true`, stored in the `$subset` variable
* We finally run the `uptime` command on our filtered list of nodes

You can see this plan in action by running:

```bash
bolt plan run exercise9::yesorno nodes=$NODE --modulepath ./modules
```

When run you should see output like the following. Running it multiple times should result in different output, as the return value of the task is random the command should run on a different subset of nodes each time.

```bash
[
  {
    "node": "node1",
    "status": "success",
    "result": {
      "stdout": " 23:41:49 up 8 min,  0 users,  load average: 0.00, 0.03, 0.04\n",
      "stderr": "",
      "exit_code": 0
    }
  },
  {
    "node": "node2",
    "status": "success",
    "result": {
      "stdout": " 23:41:49 up 7 min,  0 users,  load average: 0.32, 0.08, 0.05\n",
      "stderr": "",
      "exit_code": 0
    }
  }
]
```

Here we've shown how to capture the output from a task and then reuse it as part of the plan. More real-world uses for this might include:

* A plan which uses a task to check how long since a machine was last rebooted, and then runs another task to reboot the machine only on nodes that have been up for more than a week
* A plan which uses a task to identify the operating system of a machine and then run a different task on each different operating system

# Write a plan which handles errors

By default, any task or command that fails will cause the plan to abort immediately. To see this behavior in action, save the following as `modules/exercise9/plans/error.pp`:

```puppet
plan exercise9::error (TargetSpec $nodes) {
  $results = run_command('false', $nodes)
  if $results.ok {
    notice("The command succeeded")
  } else {
    notice("The command failed")
  }
}
```

This plan runs a command that we know will fail (`false`) and collects the result. It then uses the `ok` function to check if the command succeeded on every node, and prints a message based on that.

Run this plan to see what happens:

```bash
bolt plan run exercise9::error nodes=$NODE --modulepath ./modules
```

You should see output like the following:

```bash
Plan aborted: run_command 'false' failed on 3 nodes
[...]
```

This shows that the plan stopped executing immediately after the `run_command()` failed, so we didn't see either of the notices.

For our error-handling code to execute, we need to prevent the plan from stopping immediately on error. We can do that by passing `_catch_errors => true` to `run_command`. `_catch_errors` will make `run_command` return a `ResultSet` like normal, even if the command fails.

Save this new plan as `modules/exercise9/plans/catch_error.pp`:

```puppet
plan exercise9::catch_error (TargetSpec $nodes) {
  $results = run_command('false', $nodes, _catch_errors => true)
  if $results.ok {
    notice("The command succeeded")
  } else {
    notice("The command failed")
  }
}
```

Run this plan to see the difference:

```bash
bolt plan run exercise9::catch_error nodes=$NODE --modulepath ./modules
```

Now the `notice` statement gets executed and we see our output:

```bash
Notice: Scope(<module>/exercise9/plans/catch_error.pp, 7): The command failed
```

The `_catch_errors` argument can be passed to `run_command`, `run_task`, `run_script`, and `file_upload`.

# Next steps

Congratulations, you should now have a basic understanding of `bolt` and Puppet Tasks. Here are a few ideas for what to do next:

* Explore content on the [Puppet Tasks Playground](https://github.com/puppetlabs/tasks-playground)
* Get reusable tasks and plans from the [Task Modules Repo](https://github.com/puppetlabs/task-modules)
* Search Puppet Forge for [Tasks](https://forge.puppet.com/modules?with_tasks=yes)
* Start writing Tasks for one of your existing Puppet modules
* Head over to the [Puppet Slack](https://slack.puppet.com/) and talk to the `bolt` developers and other users
* Try out the [Puppet Development Kit](https://puppet.com/download-puppet-development-kit) [(docs)](https://docs.puppet.com/pdk/latest/index.html) which has a few features to make authoring tasks even easier
