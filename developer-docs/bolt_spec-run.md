# BoltSpec::Run
### Overview
The `BoltSpec::Run` module is intended to provide a method of executing bolt in process from tests or scripts. This documentation is meant to describe the available methods and point to examples.

## Configuration

### Config
Bolt configuration data can be passed with the `:config` key in the options hash for each method. This has the highest priority. 

In order to avoid passing the same config option every time you want to use it each method will use `bolt_config` if it is available in scope and no config has been passed in the `options` hash. 

### Inventory (inventory.yaml)
Bolt inventory data normally found in `inventory.yaml` can be passed with the `:inventory` key in the options hash for each method. This has the highest priority. 

In order to avoid passing the same config option every time you want to use it each method will use `bolt_inventory` if it is available in scope and no config has been passed in the `options` hash. 

## Beaker compatibility
Beaker defines an `assert` method in global scope which causes a conflict with a parameter in bolt. In order to use BoltSpec with beaker you must add `require 'bolt_spec/run'` before `beaker`. See https://tickets.puppetlabs.com/browse/BOLT-1159

## Module Methods

### run_task
Run a task against specified target with given configuration

**parameters**
- `task_name`, String, *required*, Name of task to run
- `targets`, String, *required*, String representation of target(s) (could be a comma separated list, group name, uri, etc)
- `params`, Hash, *required*, Task parameters, keys should be strings.
- `options`, Hash, *optional*, Default options are `config` and `inventory` with value nil. Keys should be symbols.

**return**

Array of result hashes

**result hash**
- `node`, String, Target name task was run on
- `type`, String, This should always be 'task'
- `object`, String, Task name
- `status`, String, Task result status
- `result`, Hash, Hash of task specific results

**example**

The result for a task that echoes the content of a `message` parameter with invocation.
```
[1] pry(#<BoltExample>)> run_task('bolt_spec_example', 'localhost', 'message' => 'hi')
=> [{"node"=>"localhost",
  "type"=>"task",
  "object"=>"bolt_spec_example",
  "status"=>"success",
  "result"=>{"_output"=>"hi\n"}}]
```

### run_plan
Run a plan against specified target with given configuration

**parameters**
- `plan_name`, String, *required*, Name of task to run
- `params`, Hash, *required*, Plan parameters, keys should be strings.
- `options`, Hash, *optional*, Default options are `config` and `inventory` with value nil. Keys should be symbols.

**return**

Hash

**result hash**
- `status`, String, Pask result status
- `value`, The value the plan returns

**example**

The result for a plan that returns the result of a run_command.
```
[2] pry(#<BoltExample>)> run_plan('bolt_spec_example', 'nodes' => 'localhost')
=> {"status"=>"success",
 "value"=>
  [{"node"=>"localhost",
    "type"=>"command",
    "object"=>"echo hi",
    "status"=>"success",
    "result"=>{"stdout"=>"hi\n", "stderr"=>"", "exit_code"=>0}}]}
```

### run_command
Run a command against specified target with given configuration

**parameters**
- `command`, String, *required*, The command to run
- `targets`, String, *required*, String representation of target(s) (could be a comma separated list, group name, uri, etc)
- `options`, Hash, *optional*, Default options are `config` and `inventory` with value nil. Keys should be symbols.

**return**

Array of result hashes

**result hash**
- `node`, String, Target name command was run on
- `type`, String, This should always be 'command'
- `object`, String, Command that was executed
- `status`, String, Command result status
- `result`, Hash, Hash of command specific results (keys include `stdout`, `stderr` and `exit_code`)

**example**

Echo the string "hi" on localhost.
```
[3] pry(#<BoltExample>)> run_command('echo hi', 'localhost')
=> [{"node"=>"localhost",
  "type"=>"command",
  "object"=>"echo hi",
  "status"=>"success",
  "result"=>{"stdout"=>"hi\n", "stderr"=>"", "exit_code"=>0}}]

```


### run_script
Run a script against specified target with given configuration

**parameters**
- `script`, String, *required*, The path to the script to be executed
- `targets`, String, *required*, String representation of target(s) (could be a comma separated list, group name, uri, etc)
- `arguments`, String or Array, *optional*, Positional arguments to call the script with
- `options`, Hash, *optional*, Default options are `config` and `inventory` with value nil and `options` with default value of an empty 
hash. Keys should be symbols.

**return**

Array of result hashes

**result hash**
- `node`, String, Target name script was run on
- `type`, String, This should always be 'script'
- `object`, String, Script that was executed
- `status`, String, Script result status
- `result`, Hash, Hash of command specific results (keys include `stdout`, `stderr` and `exit_code`)

**example**

Run a script that echoes the value of a positional argument.
```
[4] pry(#<BoltExample>)> run_script(File.expand_path('tasks/init.sh', Dir.pwd), 'localhost', ['hi'])
=> [{"node"=>"localhost",
  "type"=>"script",
  "object"=>
   "/home/cas/working_dir/bolt/Boltdir/site/bolt_spec_example/tasks/init.sh",
  "status"=>"success",
  "result"=>{"stdout"=>"hi\n", "stderr"=>"", "exit_code"=>0}}]
```

### upload_file
Upload local file to specified target with given configuration

**parameters**
- `source`, String, *required*, The path to the local file to be uploaded
- `dest`, String, *required*, The path on the remote target to upload file to
- `targets`, String, *required*, String representation of target(s) (could be a comma separated list, group name, uri, etc)
- `options`, Hash, *optional*, Default options are `config` and `inventory` with value nil and `options` with default value of an empty 
hash. Keys should be symbols.

**return**

Array of result hashes

**result hash**
- `node`, String, Target name file was uploaded to
- `type`, String, This should always be 'upload'
- `object`, String, Local file that was uploaded
- `status`, String, Upload result status
- `result`, Hash, Hash of upload specific results (keys include `_output`)

**example**

Upload a file.
```
[5] pry(#<BoltExample>)> upload_file(File.expand_path('tasks/init.sh', Dir.pwd), '/tmp/init.sh', 'localhost')
=> [{"node"=>"localhost",
  "type"=>"upload",
  "object"=>
   "/home/cas/working_dir/bolt/Boltdir/site/bolt_spec_example/tasks/init.sh",
  "status"=>"success",
  "result"=>
   {"_output"=>
     "Uploaded '/home/cas/working_dir/bolt/Boltdir/site/bolt_spec_example/tasks/init.sh' to 'localhost:/tmp/init.sh'"}}]

```

### apply_manifest
Apply manifest code on specified target

**parameters**
- `manifest`, String, *required*, The path to the manifest file to be executed, or a string of manifest code for use with the `execute` option.
- `targets`, String, *required*, String representation of target(s) (could be a comma separated list, group name, uri, etc)
- `options`, Hash, *optional*, Default options are `config` and `inventory` with value nil, `execute` and `noop` with default value `false`. Setting `execute` to true indicates the `manifest` is a string of code to execute instead of a path to a file. Keys should be symbols.

**return**

Array of result hashes

**result hash**
- `node`, String, Target name file was uploaded to
- `type`, String, This should always be 'apply'
- `object`, Null, This should be null
- `status`, String, Apply result status
- `result`, Hash, Hash of apply specific results (keys include `report`, and `_output`)

**example**

Apply a string of puppet code.
```
[6] pry(#<BoltExample>)> apply_manifest("package { \"vim\": ensure => present, }", 'puppet_node', execute: true)
=> [{"node"=>"ssh://root:root@0.0.0.0:20022",
  "type"=>"apply",
  "object"=>nil,
  "status"=>"success",
  "result"=>
   {"report"=>
     {"host"=>"13abe3eff000.corp.puppetlabs.net",
      "time"=>"2019-04-02T16:19:43.070397705+00:00",
      "configuration_version"=>1554221980,
      "transaction_uuid"=>nil,
      "report_format"=>10,
      ****** TRUNCATED ****************
    },
    "_output"=>"changed: 1, failed: 0, unchanged: 0 skipped: 0, noop: 0"}}]

```

### Example
The example in `bolt/developer-docs/examples/bolt-spec-example.rb` shows how to use the `BoltSpec::Run` module to run a task that writes to a file and verify the task completed as expected by running a command to examine the contents. It is important to note how the `bolt_config` and `bolt_inventory` methods are defined such that using an instance of the `BoltRunner` class allows you to use the `BoltSpec::Run` module methods configured according to those methods. It is possible to override the configuration defined in the `bolt_{config,inventory}` methods by specifying a `config` or `inventory` in a particular `BoltSpec::Run` method.

The example also shows how to iterate over a result set and check the status of the task run on a target. In this case failure results are collected in an array to be printed out, but presumably would be used for more processing or a retry. 

**Example Script**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bolt_spec/run'
require 'json'

class RunBolt
  include BoltSpec::Run

  # Set config and inventory for BoltSpec
  def bolt_config
    {
      'modulepath' => __dir__
    }
  end

  def bolt_inventory
    { 'nodes' => [{ 'name' => 'localhost', 'alias' => 'sample_target' }] }
  end
end

runner = RunBolt.new
# Use bolt_spec_example task to write a message to a file
test_file = ARGV[0] || '/tmp/test'
# Run task to write content to file
results = runner.run_task('bolt_spec_example', 'sample_target', 'file' => test_file, 'content' => 'hi')
# Iterate over array of result hashes and store the failures
failed_results = results.each_with_object([]) do |res, arr|
  if res['status'] == 'success'
    # Upon sucessful task completion run command to show what was printed to file
    command_results = runner.run_command("cat #{test_file}", 'sample_target')
    puts JSON.pretty_generate(command_results)
  else
    arr << res
  end
end
# Print any failures (or presumably retry, etc)
failed_results.each { |r| puts JSON.pretty_generate(r) } if failed_results.any?
# Clean up file
File.delete(test_file)
```

**Invocation and Result**

The following invocation executes the script with the tempfile set to `/tmp/foo`. The task was run successfully on a single target (localhost) and the result of the `run_command` is pretty printed.
```
cas@cas-ThinkPad-T460p:~/working_dir/bolt$ bundle exec developer-docs/examples/bolt-spec-example.rb /tmp/foo
[
  {
    "node": "localhost",
    "type": "command",
    "object": "cat /tmp/foo",
    "status": "success",
    "result": {
      "stdout": "hi",
      "stderr": "",
      "exit_code": 0
    }
  }
]
```
