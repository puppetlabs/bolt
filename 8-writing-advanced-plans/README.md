# Writing advanced Plans

> **Difficulty**: Intermediate

> **Time**: Approximately 10 minutes

In this exercise you will further explore Puppet Plans and see how to use the output of tasks as input to tasks in the plan.

- [Write a plan which uses input and output](#write-a-plan-which-uses-input-and-output)

# Prerequisites

For the following exercises you should already have `bolt` installed and have a few nodes (either Windows or Linux) available to run commands against. The following guides will help:

1. [Installing Bolt](../1-installing-bolt)
1. [Acquiring nodes](../2-acquiring-nodes)

It is also useful to have some familiarity with writing and running Plans with `bolt`. The following exercise is recommended:

1. [Running Commands](../7-writing-plans)

# Write a plan which uses input and output

In the previous exercise we ran tasks and commands within the context of a plan, but we didn't capture the return values or use those values in subsequent steps. The ability to use the output of a task as the input to another task allows for creating much more complex and powerful plans.

First lets create a task. This will print a JSON structure with an `answer` key with a value of true or false. The important thing to note is the use of JSON to structure our return value. Save the following as `modules/exercise8/tasks/yesorno.py`:

```python
#! /usr/bin/env python

"""
This script returns a JSON string with a single key, answer which
has a boolean value. It should flip between returning true and false
at random
"""

import json
import random

print(json.dumps({'answer': bool(random.getrandbits(1))}))
```

Then we can write out the plan. Save the following as `modules/exercise8/plans/yesorno.pp`:

```puppet
plan exercise8::yesorno(String $nodes) {
  $all = $nodes.split(",")
  $results = run_task('exercise8::yesorno', $all)
  $subset = $all.filter |$node| { $results[$node][answer] == true }
  run_command("uptime", $subset)
}
```

In the above plan we:

* Accept a comma-separated list of nodes
* Run the `exercise8::yesorno` task from above on all of our nodes
* Store the results of running the task in the variable `$results`. This will contain a `Struct` containing the node names and the data parsed from the JSON response from the task
* We filter the list of nodes into the `$subset` variable for only those that answered `true`
* We finally run the `uptime` command on our filtered list of nodes

You can see this plan in action by running:

```bash
bolt plan run exercise8::yesorno nodes=<nodes> --modules ./modules
```

When run you should see output like the following. Running it multiple times should result in different output, as the return value of the task is random the command should run on a different subset of nodes each time.

```bash
ExecutionResult({'node1' => {'stdout' => " 20:53:10 up  1:42,  0 users,  load average: 0.60, 0.42, 0.21\n", 'stderr' => '', 'exit_code' => 0}, 'node2' => {'stdout' => " 20:53:10 up  1:42,  0 users,  load average: 0.60, 0.42, 0.21\n", 'stderr' => '', 'exit_code' => 0}})
```

Here we've shown how to capture the output from a task and then reuse it as part of the plan. More real-world uses for this might include:

* A plan which uses a task to check how long since a machine was last rebooted, and then runs another task to reboot the machine only on nodes that have been up for more than a week
* A plan which uses a task to identify the operating system of a machine and then run a different task on each different operating system

# Next steps

Congratulations, you should now have a basic understanding of `bolt` and Puppet Tasks. Here are a few ideas for what to do next:

* Explore content on the [Puppet Tasks Playground](https://github.com/puppetlabs/tasks-playground)
* Get reusable tasks and plans from the [Task Modules Repo](https://github.com/puppetlabs/task-modules)
* Search Puppet Forge for [Tasks](https://forge.puppet.com/modules?with_tasks=yes)
* Start writing Tasks for one of your existing Puppet modules
* Head over to the [Puppet Slack](https://slack.puppet.com/) and talk to the `bolt` developers and other users
* Try out the [Puppet Development Kit](https://puppet.com/download-puppet-development-kit) [(docs)](https://docs.puppet.com/pdk/latest/index.html) which has a few features to make authoring tasks even easier
