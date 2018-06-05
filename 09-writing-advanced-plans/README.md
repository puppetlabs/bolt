# Writing advanced Plans

> **Difficulty**: Intermediate

> **Time**: Approximately 10 minutes

In this exercise you will further explore Puppet Plans:

- [Write a plan which uses input and output](#write-a-plan-which-uses-input-and-output)
- [Write a plan with custom Ruby functions](#write-a-plan-with-custom-ruby-functions)
- [Write a plan which handles errors](#write-a-plan-which-handles-errors)

# Prerequisites
Complete the following before you start this lesson:

1. [Installing Bolt](../01-installing-bolt)
1. [Setting up test nodes](../02-acquiring-nodes)
1. [Writing plans](../07-writing-plans)

# Write a plan which uses input and output

In the previous exercise you ran tasks and commands within the context of a plan. Now you will create a task that captures the return values and uses those values in subsequent steps. The ability to use the output of a task as the input to another task allows for creating much more complex and powerful plans. Real-world uses for this might include:

* A plan that uses a task to check how long since a machine was last rebooted, and then runs another task to reboot the machine on nodes that have been up for more than a week.
* A plan that uses a task to identify the operating system of a machine and then run a different task on each different operating system.

1. Create a task that prints a JSON structure with an `answer` key with a value of true or false. Save the task as `modules/exercise9/tasks/yesorno.py`.
    
    **Note:** JSON is used to structure the return value. 

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

3. Create a plan and save it as `modules/exercise9/plans/yesorno.pp`:

    ```puppet
    plan exercise9::yesorno (TargetSpec $nodes) {
      $results = run_task('exercise9::yesorno', $nodes)
      $subset = $results.filter |$result| { $result[answer] == true }.map |$result| { $result.target }
      return run_command("uptime", $subset)
    }
    ```
    
    This plan: 
    
    * Accepts a comma-separated list of nodes
    * Runs the `exercise9::yesorno` task from above on all of your nodes
    * Stores the results of running the task in the variable `$results`. This will contain a `ResultSet` containing a list of `Result` objects for each node and the data parsed from the JSON response from the task.
    * Filters the list of results to get the node names for only those that answered `true`, stored in the `$subset` variable.
    * Runs the `uptime` command on the filtered list of nodes.

4. Run the plan. 

    ```bash
    bolt plan run exercise9::yesorno nodes=all --modulepath ./modules
    ```
    The result:
    ```
    Starting: task exercise9::yesorno on node1, node2, node3
    Finished: task exercise9::yesorno with 0 failures in 0.95 sec
    Starting: command 'uptime' on node2, node3
    Finished: command 'uptime' with 0 failures in 0.43 sec
    [
      {
        "node": "node2",
        "status": "success",
        "result": {
          "stdout": " 20:02:39 up  4:18,  0 users,  load average: 0.03, 0.02, 0.05\n",
          "stderr": "",
          "exit_code": 0
        }
      },
      {
        "node": "node3",
        "status": "success",
        "result": {
          "stdout": " 20:02:39 up  4:18,  0 users,  load average: 0.00, 0.01, 0.05\n",
          "stderr": "",
          "exit_code": 0
        }
      }
    ]

    ```
    **Note:** Running the plan multiple times results in different output. As the return value of the task is random, the command runs on a different subset of nodes each time.

# Write a plan with custom Ruby functions

Bolt supports a powerful extension mechanism via Puppet functions. These are functions written in Puppet or Ruby that are accessible from within plans, and are in fact how many Bolt features are implemented. You can declare Puppet functions within a module and use them in your plans. Many existing Puppet functions, such as `length` from [puppetlabs-stdlib], can be used in plans. 

1. Save the following as `modules/exercise9/plans/count_volumes.pp`:

    ```puppet
    plan exercise9::count_volumes (TargetSpec $nodes) {
      $result = run_command('df', $nodes)
      return $result.map |$r| {
        $line_count = $r['stdout'].split("\n").length - 1
        "${$r.target.name} has ${$line_count} volumes"
      }
    }
    ```

2. To use the `length` function, which accepts a `String` type so it can be invoked directly on a string, install it locally:

    ```bash
    git clone https://github.com/puppetlabs/puppetlabs-stdlib ./modules/stdlib
    ```

3. Run the plan.

    ```bash
    bolt plan run exercise9::count_volumes nodes=all --modulepath ./modules
    ```
    The result:
    ```bash
    Starting: command 'df' on node1, node2, node3
    Finished: command 'df' with 0 failures in 0.5 sec
    [
      "node1 has 7 volumes",
      "node2 has 7 volumes",
      "node3 has 7 volumes"
    ]
    ```

4. Write a function to list the unique volumes across your nodes and save the function as `modules/exercise9/lib/puppet/functions/unique.rb`. A helpful function for this would be `unique`, but [puppetlabs-stdlib] includes a Puppet 3-compatible version that can't be used. Not all Puppet functions can be used with Bolt.

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

5. Write a plan that collects the last column of each line output by `df` (except the header), and prints a list of unique mount points. Save the plan as `modules/exercise9/plans/unique_volumes.pp`.

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
    
      return $volumes.unique
    }
    ```
7. Run the plan. 

    ```bash
    bolt plan run exercise9::unique_volumes nodes=all --modulepath ./modules
    ```
    The result:
    ```
    Starting: command 'df' on node1, node2, node3
    Finished: command 'df' with 0 failures in 0.53 sec
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

# Write a plan which handles errors

By default, any task or command that fails causes a plan to abort immediately. You must add error handling to a plan to prevent it from stopping this way. 

1. Save the following plan as `modules/exercise9/plans/error.pp`. This plan runs a command that fails (`false`) and collects the result. It then uses the `ok` function to check if the command succeeded on every node, and prints a message based on that.

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


2. Run the plan. 

    ```bash
    bolt plan run exercise9::error nodes=all --modulepath ./modules
    ```
    The result:
    ```
    Starting: command 'false' on node1, node2, node3
    Finished: command 'false' with 3 failures in 0.53 sec
    {
      "kind": "bolt/run-failure",
      "msg": "Plan aborted: run_command 'false' failed on 3 nodes",
      "details": {
        "action": "run_command",
        "object": "false",
        "result_set": [...]
      }
    }
    ```

    Because the plan stopped executing immediately after the `run_command()` failed, no message was returned.

3. Save the following new plan as `modules/exercise9/plans/catch_error.pp`. To prevent the plan from stopping immediately on error it passes `_catch_errors => true` to `run_command`. This returns a `ResultSet` like normal, even if the command fails.
    
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

2. Run the plan and execute the `notice` statement.

    ```bash
    bolt plan run exercise9::catch_error nodes=all --modulepath ./modules
    ```
    The result:
    ```
    Starting: command 'false' on node1, node2, node3
    Finished: command 'false' with 3 failures in 0.47 sec
    The command failed
    Plan completed successfully with no result

    ```

**Tip:** You can pass the  `_catch_errors` to `run_command`, `run_task`, `run_script`, and `file_upload`.

# Next steps
Now that you have learned about writing advanced plans you can deploy an app with bolt! 

[Deploying and Application](../10-deploying-an-application)


[puppetlabs-stdlib]: https://github.com/puppetlabs/puppetlabs-stdlib
