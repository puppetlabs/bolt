# Writing advanced Plans

> **Difficulty**: Intermediate

> **Time**: Approximately 10 minutes

In this exercise you will further explore Puppet Plans:

- [Write a plan which uses input and output](#write-a-plan-which-uses-input-and-output)
- [Write a plan with custom Ruby functions](#write-a-plan-with-custom-ruby-functions)
- [Write a plan which handles errors](#write-a-plan-which-handles-errors)

# Prerequisites

For the following exercises you should already have `bolt` installed and have a few nodes (either Windows or Linux) available to run commands against. The following guides will help:

1. [Installing Bolt](../1-installing-bolt)
1. [Acquiring nodes](../2-acquiring-nodes)

It is also useful to have some familiarity with writing and running Plans with `bolt`. The following exercise is recommended:

1. [Running Commands](../7-writing-plans)

# Write a plan which uses input and output

In the previous exercise we ran tasks and commands within the context of a plan, but we didn't capture the return values or use those values in subsequent steps. The ability to use the output of a task as the input to another task allows for creating much more complex and powerful plans.

First lets create a task. This will print a JSON structure with an `answer` key with a value of true or false. The important thing to note is the use of JSON to structure our return value. Save the following as `modules/exercise9/tasks/yesorno.py`:

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

# Write a plan with custom Ruby functions

Bolt supports a powerful extension mechanism via Puppet functions. These are functions written in Puppet or Ruby that are accessible from within plans, and are in fact how many Bolt features are implemented. You can declare Puppet functions within a module and use them in your plans. Many existing Puppet functions, such as `length` from [puppetlabs-stdlib], can be used in plans. Here we'll provide examples of using and writing custom Puppet functions in Ruby.

Let's use the `length` function to print how many volumes are on each of our test nodes. Save the following as `modules/exercise9/plans/count_volumes.pp`:

```puppet
plan exercise9::count_volumes (TargetSpec $nodes) {
  $result = run_command('df', $nodes)
  $result.map |$r| {
    $line_count = $r['stdout'].split("\n").length - 1
    "${$r.target.name} has ${$line_count} volumes"
  }
}
```

The `length` function accepts a `String` type, so it can be invoked directly on a string. To use that function, we'll need to install it locally:

```bash
git clone https://github.com/puppetlabs/puppetlabs-stdlib ./modules/stdlib
```

Then run the plan to see what happens:

```bash
bolt plan run exercise9::count_volumes nodes=$NODE --modulepath ./modules
```

You should see output like the following:

```bash
2018-02-22T15:33:21.666706 INFO   Bolt::Executor: Starting command run 'df -h' on ["node1", "node2", "node3"]
2018-02-22T15:33:21.980383 INFO   Bolt::Executor: Ran command 'df -h' on 3 nodes with 0 failures
[
  "node1 has 7 volumes",
  "node2 has 7 volumes",
  "node3 has 7 volumes"
]
```

Unfortunately not all Puppet functions can be used with Bolt. Let's write a plan to list the unique volumes across our nodes. A helpful function for this would be `unique`, but [puppetlabs-stdlib] includes a Puppet 3-compatible version that we can't use.

Let's write our own. Save the following as `modules/exercise9/lib/puppet/functions/unique.rb`:

```ruby
Puppet::Functions.create_function(:unique) do
  dispatch :unique do
    param 'Array[Data]', :vals
  end

  def unique(vals)
    vals.uniq
  end
end
```

Then save the following as `modules/exercise9/plans/unique_volumes.pp`:

```puppet
plan exercise9::unique_volumes (TargetSpec $nodes) {
  $result = run_command('df', $nodes)
  $volumes = $result.reduce([]) |$arr, $r| {
    $lines = $r['stdout'].split("\n")[1,-1]
    $volumes = $lines.map |$line| {
      $line.split(' ')[-1]
    }
    $arr + $volumes
  }

  $volumes.unique
}
```

This plan collects the last column of each line output by `df` (except the header), and prints a list of unique mount points. Run the plan to see it in action:

```bash
bolt plan run exercise9::unique_volumes nodes=$NODE --modulepath ./modules
```

You should see output like the following:

```bash
2018-02-22T15:48:51.992621 INFO   Bolt::Executor: Starting command run 'df' on ["node1", "node2", "node3"]
2018-02-22T15:48:52.305331 INFO   Bolt::Executor: Ran command 'df' on 3 nodes with 0 failures
[
  "/",
  "/dev",
  "/dev/shm",
  "/run",
  "/sys/fs/cgroup",
  "/boot",
  "/run/user/1000"
]
```

See [Puppet's custom function docs](https://puppet.com/docs/puppet/5.4/functions_basics.html) for more on writing custom functions.

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

[puppetlabs-stdlib]: https://github.com/puppetlabs/puppetlabs-stdlib