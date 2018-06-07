# Writing Plans

> **Difficulty**: Intermediate

> **Time**: Approximately 10 minutes

In this exercise you will discover Puppet Plans and how to run them with Bolt. 

- [Write a plan using run_command](#write-a-plan-using-run_command)
- [Write a plan using run_task](#write-a-plan-using-run_task)

# Prerequisites
Complete the following before you start this lesson:

1. [Installing Bolt](../01-installing-bolt)
1. [Setting up test nodes](../02-acquiring-nodes)
1. [Running Commands](../03-running-commands)

# About Plans 

Use plans when you want to run several commands together across multiple nodes. For instance to remove a node from a load balancer before you deploy the new version of the application, or to clear a cache after you re-index a search engine.

You can link a set of commands, scripts, and tasks together, and add parameters to them so they are easy to reuse. While you write plans in the Puppet language, you don't need to install Puppet to use them.


# Write a plan using run_command

Create a simple plan that runs a command on a list of nodes.

1. Save the following as `modules/exercise7/plans/command.pp`:

    ```puppet
    plan exercise7::command (TargetSpec $nodes) {
      run_command("uptime", $nodes)
    }
    ```

2. Run the plan:

    ```
    bolt plan run exercise7::command nodes=node1 --modulepath ./modules
    ```
    The result:
    ```    
    Starting: command 'uptime' on node1
    Finished: command 'uptime' with 0 failures in 0.45 sec
    Plan completed successfully with no result

    ```

    **Note:**

    * `nodes` is passed as an argument like any other, rather than a flag. This makes plans flexible when it comes to taking lists of different types of nodes or generating the list of nodes in code within the plan.

    * Use the `TargetSpec` type to denote nodes; it allows passing a single string describing a target URI or a comma-separated list of strings as supported by the `--nodes` argument to other commands. It also accepts an array of Targets, as resolved by calling the [`get_targets` method](https://puppet.com/docs/bolt/0.x/writing_plans.html#calling-basic-plan-functions). You can iterate over Targets without needing to do your own string splitting, or as resolved from a group in an [inventory file](https://puppet.com/docs/bolt/0.x/inventory_file.html).


# Write a plan using run_task
Create a task and then create a plan that uses the task.

1. Save the following task as `modules/exercise7/tasks/write.sh`. The task accepts a filename and some content and saves a file to `/tmp`.
    
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

2. Run the task directly with the following command:

    ```
    bolt task run exercise7::write filename=hello message=world --nodes=node1 --modulepath ./modules --debug
    ```
    
    **Note:** In this case the task doesn't output anything to stdout. It can be useful to trace the running of the task, and for that the `--debug` flag is useful. Here is the output when run with debug:
    
    ```
    Did not find config for node1 in inventory
    Started with 100 max thread(s)
    ModuleLoader: module 'boltlib' has unknown dependencies - it will have all other modules visible
    Did not find config for node1 in inventory
    Starting: task exercise7::write on node1
    Authentication method 'gssapi-with-mic' is not available
    Running task exercise7::write with '{"filename"=>"hello", "message"=>"world"}' via  on ["node1"]
    Started on node1...
    Running task run 'Task({'name' => 'exercise7::write', 'implementations' => [{'name' => 'write.sh', 'path' => '/Users/username/puppetlabs/tasks-hands-on-lab/07-writing-plans/modules/exercise7/tasks/write.sh', 'requirements' => []}], 'input_method' => undef})' on node1
    Opened session
    Executing: mktemp -d
    stdout: /tmp/tmp.mJo9THENdL

    Command returned successfully
    Executing: chmod u\+x /tmp/tmp.mJo9THENdL/write.sh
    Command returned successfully
    Executing: PT_filename=hello PT_message=world /tmp/tmp.mJo9THENdL/write.sh
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
3. Write a plan that uses the task you created. Save the following as `modules/exercise7/plans/writeread.pp`:

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

    **Note:**
    
    * The plan takes three arguments, one of which (`message`) has a default value. We'll see shortly how Bolt uses that to validate user input.
    * First you run the `exercise7::write` task from above, setting the arguments for the task to the values passed to the plan. This writes out a file in the `/tmp` directory.
    * Then you run a command directly from the plan, in this case to output the content written to the file in the above task.

4. Run the plan using the following command:
    
    ```
    bolt plan run exercise7::writeread filename=hello message=world nodes=node1 --modulepath ./modules
    ```
    The result:
    ```
    Starting: task exercise7::write on node1
    Finished: task exercise7::write with 0 failures in 0.88 sec
    Starting: command 'cat /tmp/hello' on node1
    Finished: command 'cat /tmp/hello' with 0 failures in 0.41 sec
    Plan completed successfully with no result
    ```

    **Note:**
    
    * `message` is optional. If it's not passed it uses the default value from the plan.
    * When running multiple steps in a plan only the last step will generate output.


# Next steps

Now that you know how to create and run basic plans with Bolt you can move on to:

[Writing advanced Tasks](../08-writing-advanced-tasks)
