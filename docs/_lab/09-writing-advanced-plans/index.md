---
title: Writing Advanced Plans
difficulty: Intermediate
time: Approximately 10 minutes
---

In this exercise you will further explore Bolt Plans:

- [Write a Plan Which Uses Input and Output](#write-a-plan-which-uses-input-and-output)
- [Write a Plan With Custom Ruby Functions](#write-a-plan-with-custom-ruby-functions)
- [Write a Plan Which Handles Errors](#write-a-plan-which-handles-errors)

## Prerequisites
Complete the following before you start this lesson:

- [Installing Bolt](../01-installing-bolt)
- [Setting Up Test Targets](../02-acquiring-targets)
- [Writing Plans](../07-writing-plans)

## About Bolt's Plan Language

The Bolt Plan language is built on [Puppet language functions](https://puppet.com/docs/puppet/6.0/lang_write_functions_in_puppet.html), meaning plans can make use of [Puppet's built-in functions](https://puppet.com/docs/puppet/6.0/function.html) and [data types](https://puppet.com/docs/puppet/6.0/lang_data.html). Additionally the Bolt Plan language adds [its own functions](https://puppet.com/docs/bolt/1.x/plan_functions.html) and data types (described in [Writing Plans](https://puppet.com/docs/bolt/1.x/writing_plans.html)). Additionally the language can be extended with [custom functions implemented in Puppet or Ruby](https://puppet.com/docs/puppet/6.0/writing_custom_functions.html). These concepts will be demonstrated in the following examples.

## Write a Plan Which Uses Input and Output

In the previous exercise you ran tasks and commands within the context of a plan. Now you will create a task that captures the return values and uses those values in subsequent steps. The ability to use the output of a task as the input to another task allows for creating much more complex and powerful plans. Real-world uses for this might include:

* A plan that uses a task to check how long since a machine was last rebooted, and then runs another task to reboot the machine on targets that have been up for more than a week.
* A plan that uses a task to identify the operating system of a machine and then run a different task on each different operating system.

Create a task that prints a JSON structure with an `answer` key with a value of true or false. Save the task as `Boltdir/site-modules/exercise9/tasks/yesorno.py`.

JSON is used to structure the return value.

```python
{% include lesson1-10/Boltdir/site-modules/exercise9/tasks/yesorno.py -%}
```

Create a plan and save it as `Boltdir/site-modules/exercise9/plans/yesorno.pp`:

```puppet
{% include lesson1-10/Boltdir/site-modules/exercise9/plans/yesorno.pp -%}
```

Data types used in this example: [TargetSpec](https://puppet.com/docs/bolt/1.x/writing_plans.html#targetspec), [ResultSet and Result](https://puppet.com/docs/bolt/1.x/writing_plans.html#concept-2722)
Functions used in this example:  [run_task](https://puppet.com/docs/bolt/1.x/plan_functions.html#run-task), [filter](https://puppet.com/docs/puppet/6.0/function.html#filter), [map](https://puppet.com/docs/puppet/6.0/function.html#map), [run_command](https://puppet.com/docs/bolt/1.x/plan_functions.html#run-command)

Run the plan.

```bash
bolt plan run exercise9::yesorno targets=linux
```

The result:

```plain
Starting: plan exercise9::yesorno
Starting: task exercise9::yesorno on target1, target2, target3
Finished: task exercise9::yesorno with 0 failures in 0.66 sec
Starting: command 'uptime' on target2, target3
Finished: command 'uptime' with 0 failures in 0.39 sec
Finished: plan exercise9::yesorno in 0.93 sec
Plan completed successfully with no result
```

Running the plan multiple times results in different output. As the return value of the task is random, the command runs on a different subset of targets each time.

## Write a Plan With Custom Ruby Functions

Bolt supports a powerful extension mechanism via Puppet functions. These are functions written in Puppet or Ruby that are accessible from within plans, and are in fact how many Bolt features are implemented. You can declare Puppet functions within a module and use them in your plans. Many existing Puppet functions, such as `length` from [puppetlabs-stdlib], can be used in plans.

Save the following as `Boltdir/site-modules/exercise9/plans/count_volumes.pp`:

```puppet
{% include lesson1-10/Boltdir/site-modules/exercise9/plans/count_volumes.pp -%}
```

To use the `length` function, which accepts a `String` type so it can be invoked directly on a string, install it locally in the `modules` directory:

```bash
git clone https://github.com/puppetlabs/puppetlabs-stdlib ./Boltdir/modules/stdlib
```

Run the plan.

```bash
bolt plan run exercise9::count_volumes targets=linux
```

The result:

```plain
Starting: plan exercise9::count_volumes
Starting: command 'df' on target1, target2, target3
Finished: command 'df' with 0 failures in 0.5 sec
[
  "target1 has 7 volumes",
  "target2 has 7 volumes",
  "target3 has 7 volumes"
]
Finished: plan exercise9::count_volumes in 0.55 sec
```

Write a function to list the unique volumes across your targets and save the function as `Boltdir/site-modules/exercise9/lib/puppet/functions/unique.rb`. A helpful function for this would be `unique`, but [puppetlabs-stdlib] includes a Puppet 3-compatible version that can't be used. Not all Puppet functions can be used with Bolt.

```ruby
{% include lesson1-10/Boltdir/site-modules/exercise9/lib/puppet/functions/unique.rb -%}
```

Write a plan that collects the last column of each line output by `df` (except the header), and prints a list of unique mount points. Save the plan as `Boltdir/site-modules/exercise9/plans/unique_volumes.pp`.

```puppet
{% include lesson1-10/Boltdir/site-modules/exercise9/plans/unique_volumes.pp -%}
```
Run the plan.

```bash
bolt plan run exercise9::unique_volumes targets=linux
```

The result:

```plain
Starting: plan exercise9::unique_volumes
Starting: command 'df' on target1, target2, target3
Finished: command 'df' with 0 failures in 0.53 sec
Starting: plan exercise9::unique_volumes in 0.55 sec
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

For more information on writing custom functions, see [Puppet's custom function docs](https://puppet.com/docs/puppet/5.5/functions_basics.html).

## Write a Plan Which Handles Errors

By default, any task or command that fails causes a plan to abort immediately. You must add error handling to a plan to prevent it from stopping this way.

Save the following plan as `Boltdir/site-modules/exercise9/plans/error.pp`. This plan runs a command that fails (`false`) and collects the result. It then uses the `ok` function to check if the command succeeded on every target, and prints a message based on that.

```puppet
{% include lesson1-10/Boltdir/site-modules/exercise9/plans/error.pp -%}
```

Run the plan.

```bash
bolt plan run exercise9::error targets=linux
```

The result:

```plain
Starting: plan exercise9::error
Starting: command 'false' on target1, target2, target3
Finished: command 'false' with 3 failures in 0.53 sec
Starting: plan exercise9::error in 0.54 sec
{
  "kind": "bolt/run-failure",
  "msg": "Plan aborted: run_command 'false' failed on 3 targets",
  "details": {
    "action": "run_command",
    "object": "false",
    "result_set": [...]
  }
}
```

Because the plan stopped executing immediately after the `run_command()` failed, no message was returned.

Save the following new plan as `Boltdir/site-modules/exercise9/plans/catch_error.pp`. To prevent the plan from stopping immediately on error it passes `_catch_errors => true` to `run_command`. This returns a `ResultSet` like normal, even if the command fails.

```puppet
{% include lesson1-10/Boltdir/site-modules/exercise9/plans/catch_error.pp -%}
```

Run the plan and execute the `out::message` statement.

```bash
bolt plan run exercise9::catch_error targets=linux
```

The result:

```plain
Starting: plan exercise9::catch_error
Starting: command 'false' on target1, target2, target3
Finished: command 'false' with 3 failures in 0.47 sec
The command failed
Starting: plan exercise9::catch_error in 0.48 sec
Plan completed successfully with no result
```

**Tip:** You can pass the  `_catch_errors` to `run_command`, `run_task`, `run_script`, and `file_upload`.

## Next Steps
Now that you have learned about writing advanced plans you can deploy an app with Bolt!

[Deploying an Application](../10-deploying-an-application)


[puppetlabs-stdlib]: https://github.com/puppetlabs/puppetlabs-stdlib
