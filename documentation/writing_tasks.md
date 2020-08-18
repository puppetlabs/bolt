# Writing tasks

Bolt tasks are similar to scripts, but they are kept in modules and can have
metadata. This allows you to reuse and share them.

You can write tasks in any programming language the targets run, such as Bash,
PowerShell, or Python. A task can even be a compiled binary that runs on the
target. Place your task in the `./tasks` directory of a module and add a
metadata file to describe parameters and configure task behavior.

For a task to run on remote *nix systems, it must include a shebang (`#!`) line
at the top of the file to specify the interpreter.

For example, the Puppet `mysql::sql` task is written in Ruby and provides the
path to the Ruby interpreter. This example also accepts several parameters as
JSON on `stdin` and returns an error.

```ruby
#!/opt/puppetlabs/puppet/bin/ruby
require 'json'
require 'open3'
require 'puppet'

def get(sql, database, user, password)
  cmd = ['mysql', '-e', "#{sql} "]
  cmd << "--database=#{database}" unless database.nil?
  cmd << "--user=#{user}" unless user.nil?
  cmd << "--password=#{password}" unless password.nil?
  stdout, stderr, status = Open3.capture3(*cmd) # rubocop:disable Lint/UselessAssignment
  raise Puppet::Error, _("stderr: ' %{stderr}') % { stderr: stderr }") if status != 0
  { status: stdout.strip }
end

params = JSON.parse(STDIN.read)
database = params['database']
user = params['user']
password = params['password']
sql = params['sql']

begin
  result = get(sql, database, user, password)
  puts result.to_json
  exit 0
rescue Puppet::Error => e
  puts({ status: 'failure', error: e.message }.to_json)
  exit 1
end
```

## Naming tasks

You use a task name to interact with a task from the Bolt command line. For
example, you can use `bolt task run puppet_agent::version --targets localhost`
to run the `puppet_agent::version` task. 

Task names are composed of one or two name segments, indicating:
-   The name of the module where the task is located.
-   The name of the task file, without the extension.

For example, in the `puppetlabs/mysql` module, the `sql` task is located at
`./mysql/tasks/sql.rb`, so the task name is `mysql::sql`. 

You can write tasks in any language that runs on the targets. Give task files
the extension for the language they are written in (such as `.rb` for Ruby), and
place them in the top level of your module's `./tasks` directory.

Each task or plan name segment must begin with a lowercase letter and:
-   Must start with a lowercase letter.
-   Can include digits.
-   Can include underscores.
-   Namespace segments must match the regular expression: `\A[a-z][a-z0-9_]*\Z`
-   The file extension must not use the reserved extensions `.md` or `.json`.

> **Note:** The task filename `init` is special: the task it defines is
> referenced using the module name only. For example, in the
> `puppetlabs-service` module, the task defined in `init.rb` is the `service`
> task.

## Task metadata

Task metadata files describe task parameters, validate input, and control how
Bolt executes the task.

Your task must have metadata to be published and shared on the Forge. Specify
task metadata in a JSON file with the naming convention `<TASKNAME>.json`. Place
this file in the module's `./tasks` folder along with your task file.

For example, the module `puppetlabs/mysql` includes the `mysql::sql` task with
the metadata file, `sql.json`.

```json
{
  "description": "Allows you to execute arbitrary SQL",
  "input_method": "stdin",
  "parameters": {
    "database": {
      "description": "Database to connect to",
      "type": "Optional[String[1]]"
    },
    "user": {
      "description": "The user",
      "type": "Optional[String[1]]"
    },
    "password": {
      "description": "The password",
      "type": "Optional[String[1]]",
      "sensitive": true
    },
     "sql": {
      "description": "The SQL you want to execute",
      "type": "String[1]"
    }
  }
}
```

### Task metadata fields

The following table shows task metadata keys, values, and default values.

| Metadata key | Description | Value | Default |
|------------|-----------|-----|-------|
| `"description"` | A description of what the task does. | String | None |
| `"input_method"` | What input method the task runner uses to pass parameters to the task. | <ul><li>`environment`</li><li>`stdin`</li><li>`powershell`</li></ul> | `powershell` for `.ps1` tasks. </br> Both `environment` and `stdin` for other tasks. |
| `"parameters"` | The parameters or input the task accepts listed with a puppet type string and optional description. For more information, see [Adding parameters to metadata](#adding-parameters-to-metadata). | Array of objects describing each parameter | None |
| `"puppet_task_version"` | The version of the spec used. | Integer | `1` (This is the only valid value.) |
| `"supports_noop"` | Whether the task supports no-op mode. Required for the task to accept the `--noop` option on the command line. | Boolean | `false` |
| `"implementations"` | A list of task implementations and the requirements used to select one to run. See [Single and cross-platform tasks](#single-and-cross-platform-tasks) for usage information. |Array of Objects describing each implementation | None |
| `"files"` | A list of files to be provided when running the task, addressed by module. See [Sharing task code](#sharing-task-code) for usage information. |Array of Strings | None |
| `"private"` | Do not display task by default when listing for UI. | Boolean | `false` |
| `"remote"` | Whether this task is allowed to run on a proxy target, from which it will interact with a remote target. Remote tasks must not change state locally when the `_targets` meta parameter is set. For more information, see [Writing remote tasks](#writing-remote-tasks) | Boolean | `false` |

### Common task data types

Task metadata can accept most Puppet data types.

| Type | Description |
|----|-----------|
| `String` | Accepts any string. |
| `String[1]` | Accepts any non-empty string (a string of at least length `1`). |
| `Enum[choice1, choice2]` | Accepts one of the listed choices. |
| `Pattern[/\A\w+\Z/]` | Accepts strings matching the regex `/\w+/` or non-empty strings of word characters. |
| `Integer` | Accepts integer values. JSON has no integer type so this can vary depending on input. |
| `Optional[String[1]]` | `Optional` makes the parameter optional and permits null values. Tasks have no required nullable values. |
| `Array[String]` | Matches an array of strings. |
| `Hash` | Matches a JSON object. |
| `Variant[Integer, Pattern[/\A\d+\Z/]]` | Matches an integer or a string of an integer. |
| `Boolean` | Accepts boolean values. |

**Caution:** Some types supported by Puppet can not be represented as JSON, such
as `Hash[Integer, String]`, `Object`, or `Resource`. Do not use these in tasks,
because they can never be matched.

📖 **Related information**  

For more information on Puppet data types, see [Data type
syntax](https://puppet.com/docs/puppet/latest/lang_data_type.html)

## Defining parameters in tasks

Tasks can receive input as either environment variables, a JSON hash on standard
input, or as PowerShell arguments. By default, Bolt submits parameters as both
environment variables and as JSON on `stdin`. Environment variables work well
for simple JSON types such as strings and numbers. For arrays and hashes, use
structured input instead, because parameters with undefined values (`nil`,
`undef`) passed as environment variables have the `String` value `null`. For
more information, see [Structured input and
output](#structured-input-and-output).

To add a parameter to your task as an environment variable, pass the argument
prefixed with the Puppet task prefix `PT_`.

For example, to add a `message` parameter to your task, read it from the
environment in task code as `PT_message`. When a user runs the task, they can
specify the value for the parameter on the command line as `message=hello`, and
the task runner submits the value `hello` to the `PT_message` variable.

```shell script
#!/usr/bin/env bash
echo your message is $PT_message
```

If your task must receive parameters only in a certain way, such as only
`stdin`, you can set the input method in your task metadata using
`input_method`. For more information on `input_method`, see [Task metadata
reference](#task-metadata-fields).

### Defining parameters in Windows

For Windows tasks, you can pass parameters as environment variables, but it's
easier to write your task in PowerShell and use named arguments. By default,
tasks with a `.ps1` extension use PowerShell standard argument handling.

For example, this PowerShell task takes a process name as an argument and
returns information about the process. If the user doesn't pass a parameter, the
task returns all of the processes.

```powershell
[CmdletBinding()]
Param(
  [Parameter(Mandatory = $False)]
 [String]
  $Name
  )

if ($Name -eq $null -or $Name -eq "") {
  Get-Process
} else {
  $processes = Get-Process -Name $Name
  $result = @()
  foreach ($process in $processes) {
    $result += @{"Name" = $process.ProcessName;
                 "CPU" = $process.CPU;
                 "Memory" = $process.WorkingSet;
                 "Path" = $process.Path;
                 "Id" = $process.Id}
  }
  if ($result.Count -eq 1) {
    ConvertTo-Json -InputObject $result[0] -Compress
  } elseif ($result.Count -gt 1) {
    ConvertTo-Json -InputObject @{"_items" = $result} -Compress
  }
}
```

To pass parameters in your task as environment variables (`PT_parameter`), you
must set `input_method` in your task metadata to `environment`. To run Ruby
tasks on Windows, the Puppet agent must be installed on the targets.

### Adding parameters to metadata

To document and validate task parameters, add the parameters to the task
metadata as JSON object, `parameters`.

If a task includes `parameters` in its metadata, Bolt rejects any parameters
input to the task that aren't defined in the metadata.

In the `parameter` object, give each parameter a description and specify its
Puppet type. For a complete list of types, see the [types
documentation](https://docs.puppet.com/puppet/latest/lang_data_type.html).

For example, the following code in a metadata file describes a `provider`
parameter:

```json
"provider": {
  "description": "The provider to use to manage or inspect the service, defaults to the system service manager",
  "type": "Optional[String[1]]"
 }
```

### Defining sensitive parameters

You can define task parameters as sensitive. For example, passwords and API
keys. These values are masked when they appear in logs and API responses. When
you want to view these values, set the log file to `level: debug`.

To define a parameter as sensitive within the JSON metadata, add the
`"sensitive": true` property.

```json
{
  "description": "This task has a sensitive property denoted by its metadata",
  "input_method": "stdin",
  "parameters": {
    "user": {
      "description": "The user",
      "type": "String[1]"
    },
    "password": {
      "description": "The password",
      "type": "String[1]",
      "sensitive": true
    }
  }
}
```

### Setting default values

You can set a default value for a parameter which will be used if the parameter
isn't specified or if the parameter is specified and has a value of `Undef`. The
default will be used even if the parameter type is optional. Default values must
be valid according to the parameter's `type`.

```json
{
  "description": "This task has a parameter with a default value",
  "input_method": "stdin",
  "parameters": {
    "platform" : {
      "description": "Which operating system to provision",
      "type": "String[1]"
    },
    "count": {
      "description": "How many instances to provision",
      "type": "Integer",
      "default": 1
    }
  }
```

> **Note:** Not every version of Bolt supports parameter defaults, so you should
> either make the parameter required or explicitly check for its presence in the
> task implementation.

## Using structured input and output

If you have a task that has many options, returns a lot of information, or is
part of a task plan, consider using structured input and output with your task.

The task API is based on JSON. Task parameters are encoded in JSON, and the task
runner attempts to parse the output of the tasks as a JSON object.

Bolt can inject keys into that object, prefixed with `_`. If the task does not
return a JSON object, Bolt creates one and places the output in an `_output`
key.

### Structured input

For complex input, such as hashes and arrays, you can accept structured JSON in
your task.

By default, Bolt passes task parameters as both environment variables and as a
single JSON object on `stdin`. The JSON input allows the task to accept complex
data structures. 

To accept parameters as JSON on `stdin`, set the `params` key to accept JSON on
`stdin`:

```ruby
#!/opt/puppetlabs/puppet/bin/ruby
require 'json'

params = JSON.parse(STDIN.read)

exitcode = 0
params['files'].each do |filename|
  begin
    FileUtils.touch(filename)
    puts "updated file #{filename}"
  rescue
    exitcode = 1
    puts "couldn't update file #{filename}"
  end
end
exit exitcode
```

If your task accepts input on `stdin`, specify `"input_method": "stdin"` in the
task's `metadata.json` file, or it might not work with `sudo` for some users.

### Returning structured output

Structured output is useful if you want to use the output in another program, or
if you want to use the result of the task in a Puppet task plan.

To return structured data from your task, print only a single JSON object to
`stdout` in your task.

```python
#!/usr/bin/env python

import json
import sys
minor = sys.version_info
result = { "major": sys.version_info.major, "minor": sys.version_info.minor }
json.dump(result, sys.stdout)
```

### Returning errors in tasks

To return a detailed error message if your task fails, include an `Error` object
in the task's result.

When a task exits non-zero, Bolt checks for an error key `_error`. If one is not
present, Bolt generates a generic error and adds it to the result. If there is
no text on `stdout`, but text is present on `stderr`, the `stderr` text is
included in the message.

```json
{ "_error": {
    "msg": "Task exited 1:\nSomething on stderr",
    "kind": "puppetlabs.tasks/task-error",
    "details": { "exitcode": 1 }
}
```

An error object includes the following keys:
-   `msg` - A human readable string that appears in the UI.
-   `kind` - A standard string for machines to handle. You may share kinds
    between your modules or namespace kinds per module.
-   `details` - An object of structured data about the tasks.

Tasks can provide more details about the failure by including their own error
object in the result at `_error`.

```ruby
#!/opt/puppetlabs/puppet/bin/ruby

require 'json'

begin
  params = JSON.parse(STDIN.read)
  result = {}
  result['result'] = params['dividend'] / params['divisor']

rescue ZeroDivisionError
  result[:_error] = { msg: "Cannot divide by zero",
                      # namespace the error to this module
                      kind: "puppetlabs-example_modules/dividebyzero",
                      details: { divisor: divisor },
                    }
rescue Exception => e
  result[:_error] = { msg: e.message,
                     kind: "puppetlabs-example_modules/unknown",
                     details: { class: e.class.to_s },
                   }
end

puts result.to_json
```

## Supporting no-op in tasks

Tasks support no-operation functionality, also known as no-op mode. This
function shows what changes the task would make, without actually making those
changes.

No-op support allows a user to pass the `--noop` flag with a command to test
whether the task will succeed on all targets before making changes.

To support no-op, your task must include code that looks for the `_noop`
metaparameter.

If the user passes the `--noop` flag with their command, this parameter is set
to `true`, and your task must not make changes. You must also set
`supports_noop` to `true` in your task metadata or Bolt will refuse to run the
task in noop mode.

### No-op metadata example

```json
{
  "description": "Write content to a file.",
  "supports_noop": true,
  "parameters": {
    "filename": {
      "description": "the file to write to",
      "type": "String[1]"
    },
    "content": {
      "description": "The content to write",
      "type": "String"
    }
  }
}
```

### No-op task example

```python
#!/usr/bin/env python

import json
import os
import sys

params = json.load(sys.stdin)
filename = params['filename']
content = params['content']
noop = params.get('_noop', False)

exitcode = 0

def make_error(msg):
  error = {
      "_error": {
          "kind": "file_error",
          "msg": msg,
          "details": {},
      }
  }
  return error

try:
  if noop:
    path = os.path.abspath(os.path.join(filename, os.pardir))
    file_exists = os.access(filename, os.F_OK)
    file_writable = os.access(filename, os.W_OK)
    path_writable = os.access(path, os.W_OK)

    if path_writable == False:
      exitcode = 1
      result = make_error("Path %s is not writable" % path)
    elif file_exists == True and file_writable == False:
      exitcode = 1
      result = make_error("File %s is not writable" % filename)
    else:
      result = { "success": True , '_noop': True }
  else:
    with open(filename, 'w') as fh:
      fh.write(content)
      result = { "success": True }
except Exception as e:
  exitcode = 1
  result = make_error("Could not open file %s: %s" % (filename, str(e)))
print(json.dumps(result))
exit(exitcode)
```

## Single and cross-platform tasks

In most cases, tasks are developed for a single platform and consist of a single
executable with or without a corresponding metadata file. For
instance, `./mysql/tasks/sql.rb` and `./mysql/tasks/sql.json`. In this case, no
other `./mysql/tasks/sql.*` files can exist.

A task can have multiple implementations, with metadata that explains when to
use each one. A primary use case for this is to support different
implementations for different target platforms, referred to as cross-platform
tasks. 

For instance, consider a module with the following files:

```
- tasks
  - sql_linux.sh
  - sql_linux.json
  - sql_windows.ps1
  - sql_windows.json
  - sql.json
```

This task has a task metadata file (`sql.json`), two implementation metadata
files (`sql_linux.json`, and `sql_windows.json`), and two executables
(`sql_linux.sh` and `sql_windows.ps1`). The implementation metadata files
document how to use the implementation directly, or mark the implementation as
private to hide it from UI lists.

For example, the `sql_linux.json` implementation metadata file contains the
following:

```json
{
  "name": "SQL Linux",
  "description": "A task to perform sql operations on linux targets",
  "private": true
}
```

The task metadata file, `sql.json`, contains an implementations section:

```json
{
  "implementations": [
    {"name": "sql_linux.sh", "requirements": ["shell"]},
    {"name": "sql_windows.ps1", "requirements": ["powershell"]}
  ]
}
```

Each implementations has a `name` and a list of `requirements`. Task
requirements correspond directly to Bolt _features_. A feature must be available
on the target in order for Bolt to use an implementation. You can specify
additional features for a target using the `set_feature` function in a Bolt
plan, or by adding `features` to your inventory file. Bolt chooses the first
implementation whose requirements are satisfied. 

Bolt defines the following features by default:
-   `puppet-agent`: Present if the target has the Puppet agent package
    installed. This feature is automatically added to hosts with the name
    `localhost`.
-   `shell`: Present if the target has a POSIX shell.
-   `powershell`: Present if the target has PowerShell.

In the above example, the `sql_linux.sh` implementation requires the `shell`
feature, and the `sql_windows.ps1` implementation requires the PowerShell
feature.

## Writing remote tasks

Some targets are hard or impossible to execute tasks on directly. In these
cases, you can write a task that runs on a proxy target and remotely interacts
with the real target.

For example, a network device might have a limited shell environment or a cloud
service might be driven only by HTTP APIs. By writing a remote task, Bolt allows
you to specify connection information for remote targets in their inventory file
and injects them into the `_target` metaparameter.

This example shows how to write a task that posts messages to Slack and reads
connection information from `inventory.yaml`:

```ruby
#!/usr/bin/env ruby
# modules/slack/tasks/message.rb

require 'json'
require 'net/http'

params = JSON.parse(STDIN.read)
# the slack API token is passed in from inventory
token = params['_target']['token']
    
uri = URI('https://slack.com/api/chat.postMessage')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

req = Net::HTTP::Post.new(uri, 'Content-type' => 'application/json')
req['Authorization'] = "Bearer #{params['_target']['token']}"
req.body = { channel: params['channel'], text: params['message'] }.to_json

resp = http.request(req)

puts resp.body
```

To prevent accidentally running a normal task on a remote target and breaking
its configuration, Bolt won't run a task on a remote target unless its metadata
defines it as remote:

```json
{
  "remote": true
}
```

Add Slack as a remote target in your inventory file:

```yaml
targets:
  - name: my_slack
    config:
      transport: remote
      remote:
        token: <SLACK_API_TOKEN>
```

Finally, make `my_slack` a target that can run the `slack::message`:

```shell script
bolt task run slack::message --targets my_slack message="hello" channel=<slack channel id>
```

## Converting scripts to tasks

To convert an existing script to a task, you can either write a task that wraps
the script, or you can add logic in your script to check for parameters in
environment variables.

> 🔩 **Tip:** In most cases, you can wrap an existing script in a simple YAML
> plan, giving you much of the same benefit of converting a script to a task
> without much effort. To learn more about wrapping scripts in YAML plans, see
> [Wrapping scripts](writing_yaml_plans.md#wrapping-scripts).

If the script is already installed on the targets, you can write a task that
wraps the script. In the task, read the script arguments as task parameters and
call the script, passing the parameters as the arguments.

If the script isn't installed, or you want to make it into a cohesive task so
that you can manage its version with code management tools, add code to your
script to check for the environment variables, prefixed with `PT_`, and read
them instead of arguments.

Given a script that accepts positional arguments on the command line:

```shell script
version=$1
[ -z "$version" ] && echo "Must specify a version to deploy && exit 1

if [ -z "$2" ]; then
  filename=$2
else
  filename=~/myfile
fi
```

To convert the script into a task, replace this logic with task variables:

```shell script
version=$PT_version #no need to validate if we use metadata
if [ -z "$PT_filename" ]; then
  filename=$PT_filename
else
  filename=~/myfile
fi
```

> **Caution**: If you intend to use a task with Puppet Enterprise and assign
> RBAC permissions, make sure the script safely handles parameters, or validate
> them to prevent shell injection vulnerabilities.

## Sharing executables

Multiple task implementations can refer to the same executable file.

Executables can access the `_task` metaparameter, which contains the task name.
For example, the following creates the tasks `service::stop` and
`service::start`, which live in the executable but appear as two separate tasks.

```
myservice/tasks/init.rb
```

```ruby
#!/usr/bin/env ruby
require 'json'

params = JSON.parse(STDIN.read)
action = params['action'] || params['_task']
if ['start',  'stop'].include?(action)
  `systemctl #{params['_task']} #{params['service']}`
end

```

```
myservice/tasks/start.json
```

```json
{
  "description": "Start a service",
  "parameters": {
    "service": {
      "type": "String",
      "description": "The service to start"
    }
  },
  "implementations": [
    {"name": "init.rb"}
  ]
}
```

```
myservice/tasks/stop.json
```

```json
{
  "description": "Stop a service",
  "parameters": {
    "service": {
      "type": "String",
      "description": "The service to stop"
    }
  },
  "implementations": [
    {"name": "init.rb"}
  ]
}
```

## Sharing task code

Multiple tasks can share common files between them. Tasks can additionally pull
library code from other modules.

To create a task that includes additional files pulled from modules, include
the `files` property in your metadata as an array of paths. A path consists of:

-   The module name.
-   One of the following directories within the module:
    -   `files` — Most helper files. This prevents the file from being treated
        as a task or added to the Puppet Ruby load path.
    -   `tasks` — Helper files that can be called as tasks on their own.
    -   `lib` — Ruby code that might be reused by types, providers, or Puppet
        functions.
-   The remaining path to a file or directory; directories must include a
    trailing slash `/`.

All path separators must be forward slashes. For example, `stdlib/lib/puppet/`.

You can include the `files` property as a top-level metadata property and as a
property of an implementation, for example:

```json
{
  "implementations": [
    {"name": "sql_linux.sh", "requirements": ["shell"], "files": ["mymodule/files/lib.sh"]},
    {"name": "sql_windows.ps1", "requirements": ["powershell"], "files": ["mymodule/files/lib.ps1"]}
  ],
  "files": ["emoji/files/emojis/"]
}
```

When a task includes the `files` property, all files listed in the top-level
property and in the specific implementation chosen for a target are copied to a
temporary directory on the target. The directory structure of the specified
files is preserved so that paths specified with the `files` metadata option are
available to tasks prefixed with `_installdir`. The task executable itself is
located in its module location under the `_installdir` as well, so other files
can be found at `../../mymodule/files/` relative to the location of the task
executable.

For example, you can create a task and metadata in a module at
`~/.puppetlabs/bolt/site-modules/mymodule/tasks/task.{json,rb}`.

**Metadata**

```json
{
  "files": ["multi_task/files/rb_helper.rb"]
}
```

**File resource**

`multi_task/files/rb_helper.rb`

```ruby
def useful_ruby
  { helper: "ruby" }
end
```

**Task**

```ruby
#!/usr/bin/env ruby
require 'json'

params = JSON.parse(STDIN.read)
require_relative File.join(params['_installdir'], 'multi_task', 'files', 'rb_helper.rb')
# Alternatively use relative path
# require_relative File.join(__dir__, '..', '..', 'multi_task', 'files', 'rb_helper.rb')
puts useful_ruby.to_json
```

**Output**

```console
Started on localhost...
Finished on localhost:
  {
    "helper": "ruby"
  }
Successful on 1 target: localhost
Ran on 1 target in 0.12 seconds
```

### Task helpers

To help with writing tasks, Bolt includes the
[python_task_helper](https://github.com/puppetlabs/puppetlabs-python_task_helper)
and
[ruby_task_helper](https://github.com/puppetlabs/puppetlabs-ruby_task_helper)
libraries. These libraries useful in demonstrating how to include code from
another module.

### Python example

Create task and metadata in a module at
`~/.puppetlabs/bolt/site-modules/mymodule/tasks/task.{json,py}`.

**Metadata**

```json
{
  "files": ["python_task_helper/files/task_helper.py"],
  "input_method": "stdin"
}
```

**Task**

```python
#!/usr/bin/env python
import os, sys
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'python_task_helper', 'files'))
from task_helper import TaskHelper

class MyTask(TaskHelper):
  def task(self, args):
    return {'greeting': 'Hi, my name is '+args['name']}

if __name__ == '__main__':
    MyTask().run()
```

**Output**

```console
$ bolt task run mymodule::task -n localhost name='Julia'
Started on localhost...
Finished on localhost:
  {
    "greeting": "Hi, my name is Julia"
  }
Successful on 1 target: localhost
Ran on 1 target in 0.12 seconds
```

### Ruby example

Create task and metadata in a new module at
`~/.puppetlabs/bolt/site-modules/mymodule/tasks/mytask.{json,rb}`.

**Metadata**

```json
{
  "files": ["ruby_task_helper/files/task_helper.rb"],
  "input_method": "stdin"
}
```

**Task**

```ruby
#!/usr/bin/env ruby
require_relative '../../ruby_task_helper/files/task_helper.rb'

# Example task that is based on the ruby_task_helper
class MyTask < TaskHelper
  def task(name: nil, **kwargs)
    { greeting: "Hi, my name is #{name}" }
  end
end

MyTask.run if $PROGRAM_NAME == __FILE__
```

**Output**

```console
$ bolt task run mymodule::mytask -n localhost name="Robert'); DROP TABLE Students;--"
Started on localhost...
Finished on localhost:
  {
    "greeting": "Hi, my name is Robert'); DROP TABLE Students;--"
  }
Successful on 1 target: localhost
Ran on 1 target in 0.12 seconds
```

## Secure coding practices for tasks

Use secure coding practices when you write tasks and help protect your system.

**Note:** The information in this topic covers basic coding practices for
writing secure tasks. It is not an exhaustive list.

One of the methods attackers use to gain access to your systems is remote code
execution, where they are able to gain access to other parts of your system and
make arbitrary changes by running an allowed script. Because Bolt executes
scripts across your infrastructure, it is important to be aware of certain
vulnerabilities, and to code tasks in a way that guards against remote code
execution.

Adding task metadata that validates input is one way to reduce vulnerability.
When you require an enumerated (`enum`) or other non-string types, you prevent
improper data from being entered. An arbitrary string parameter does not have
this assurance.

For example, if your task has a parameter that selects from several operational
modes that are passed to a shell command, instead of

```
String $mode = 'file'
```

use

```
Enum[file,directory,link,socket] $mode = file
```

If your task has a parameter that identifies a file on disk, ensure that a user
can't specify a relative path that takes them into areas where they shouldn't
be. Reject file names that have slashes.

Instead of

```
String $path
```

use

```
Pattern[/\A[^\/\\]*\z/] $path
```

In addition to these task restrictions, different scripting languages each have
their own ways to validate user input.

### PowerShell

In PowerShell, code injection exploits calls that specifically evaluate code. Do
not call `Invoke-Expression` or `Add-Type` with user input. These commands
evaluate strings as C# code.

Reading sensitive files or overwriting critical files can be less obvious. If
you plan to allow users to specify a file name or path, use `Resolve-Path` to
verify that the path doesn't go outside the locations you expect the task to
access. Use `Split-Path -Parent $path` to check that the resolved path has the
desired path as a parent.

For more information, see [PowerShell
Scripting](https://docs.microsoft.com/en-us/powershell/scripting/PowerShell-Scripting?view=powershell-6)
and [Powershell's Security Guiding
Principles](https://blogs.msdn.microsoft.com/powershell/2008/09/30/powershells-security-guiding-principles/).

### Bash

In Bash and other command shells, shell command injection takes advantage of
poor shell implementations. Put quotation marks around arguments to prevent the
vulnerable shells from evaluating them.

Because the `eval` command evaluates all arguments with string substitution,
avoid using it with user input; however you can use `eval` with sufficient
quoting to prevent substituted variables from being executed.

Instead of

```shell script
eval "echo $input"
```

use

```shell script
eval "echo '$input'"
```

These are operating system-specific tools to validate file paths: `realpath` or
`readlink -f`.

### Python

In Python malicious code can be introduced through commands like `eval`, `exec`,
`os.system`, `os.popen`, and `subprocess.call` with `shell=True`. Use
`subprocess.call` with `shell=False` when you include user input in a command or
escape variables.

Instead of

```python
os.system('echo '+input)

```

use

```python
subprocess.check_output(['echo', input])
```

Resolve file paths with `os.realpath` and confirm them to be within another path
by looping over `os.path.dirname` and comparing to the desired path.

For more information on the vulnerabilities of Python or how to escape
variables, see Kevin London's blog post on [Dangerous Python
Functions](https://www.kevinlondon.com/2015/07/26/dangerous-python-functions.html).

### Ruby

In Ruby, command injection is introduced through commands like `eval`, `exec`,
`system`, backtick (``) or `%x()` execution, or the Open3 module. You can safely
call these functions with user input by passing the input as additional
arguments instead of a single string.

Instead of

```ruby
system("echo #{flag1} #{flag2}")
```

use

```ruby
system('echo', flag1, flag2)
```

Resolve file paths with `Pathname#realpath`, and confirm them to be within
another path by looping over `Pathname#parent` and comparing to the desired
path.

For more information on securely passing user input, see the blog post [Stop
using backtick to run shell command in
Ruby](https://www.hilman.io/blog/2016/01/stop-using-backtick-to-run-shell-command-in-ruby/).

## Debugging tasks

There are several ways that you can debug tasks, including using remote
debugging libraries, using methods available in the task helper libraries,
running the task locally as a script, and redirecting `stderr` to `stdout`.

### Debug logs

Typically, Bolt only displays task output that is sent to `stdout`. However,
Bolt does log additional information about a task run, including output sent to
`stderr`, at the `debug` level. You can view these logs during a task run using
the `--log-level debug` CLI option.

```shell
$ bolt task run mytask param1=foo param2=bar -t all --log-level debug
```

### Debuggers

Many of the scripting languages you can use to write tasks have debugging
libraries available that allow you to set breakpoints and examine your task
as it executes.

Both Python and Ruby have remote debugging libraries available that make it
easy to pause execution of a task and debug the code. Using remote debugging
libraries is necessary when running tasks with Bolt since the tasks are
executed in separate threads.

PowerShell tasks can take advantage of the `Set-PSBreakpoint` cmdlet, which
sets a breakpoint in a PowerShell script and allows you to step through the
code. Since Bolt passes parameters to PowerShell tasks as named arguments,
you can easily run PowerShell tasks as scripts and use the `Set-PSBreakpoint`
cmdlet.

#### Python tasks

The `rpdb` library is a wrapper for the `pdb` library, Python's standard
debugging library. To use the `rpdb` library, you will need to install it
on every target you want to debug the task on.

> 🔩 **Tip:** In most cases, you can debug tasks by only running them on
> `localhost` instead of a list of remote targets. This avoids the need to
> establish a connection with a target, which may be difficult if your target
> restricts incoming connections.

You can install the `rpdb` library using `pip`:

```shell
$ pip install rpdb
```

Then, add the following line to your task wherever you want to begin debugging:

```python
import rpdb; rpdb.set_trace()
```

You can then open a connection to a target on port `4444` to begin debugging:

```shell
$ nc 127.0.0.1 4444

> /tmp/96a96045-0eed-4dea-a497-400b9d5c8e30/python/tasks/init.py(13)task()
-> result = num1 + num2
(Pdb)
```

📖 **Related information**
- [`rpdb` documentation](https://pypi.org/project/rpdb/)
- [`pdb` documentation](https://docs.python.org/3/library/pdb.html)

#### Ruby tasks

The `pry-remote` gem allows you to start a remote debugging session using
the `pry` gem, a standard debugging library for Ruby. To use the `pry-remote`
gem, you will need to install it on every target you want to debug the task
on.

> 🔩 **Tip:** In most cases, you can debug tasks by only running them on
> `localhost` instead of a list of remote targets. This avoids the need to
> establish a connection with a target, which may be difficult if your target
> restricts incoming connections.

If you are running the task on remote targets, you can install the `pry-remote`
gem using `gem install`:

```shell
$ gem install pry-remote
```

If you are running the task on `localhost`, you can install the `pry-remote`
gem locally using Bolt's Ruby:

```shell
$ /opt/puppetlabs/bolt/bin/gem install --user-install pry-remote
```

If you are running the task on `localhost` on Windows, run the following
command instead:

```powershell
> "C:/Program Files/Puppet Labs/Bolt/bin/gem.bat" install --user-install pry-remote
```

Then, add the following line to your task wherever you want to begin debugging:

```ruby
require 'pry-remote'; binding.remote_pry
```

You can then open a connection to a target using the `pry-remote` command:

```shell
$ pry-remote -s 127.0.0.1

Frame number: 0/4

From: /tmp/4f9dcfa3-ce0c-49e2-bcf5-8d761b202186/ruby/tasks/init.rb @ line 9 MyClass#task:

     6: def task(opts)
 =>  9:   require 'pry-remote'; binding.remote_pry
    10:
```

📖 **Related information**
- [`pry-remote` documentation](https://www.rubydoc.info/gems/pry-remote)
- [`pry` documentation](http://pry.github.io/)

#### PowerShell tasks

PowerShell tasks can take advantage of the `Set-PSBreakpoint` cmdlet to debug
tasks that are run as scripts. The `Set-PSBreakpoint` cmdlet can set a
breakpoint at a specific line of your task, pausing execution of the task
so you can examine the code and step through it line by line.

To set a breakpoint at a specific line of your task, run the `Set-PSBreakpoint`
cmdlet:

```powershell
> Set-PSBreakpoint -Script mytask.ps1 -Line <line number>
```

You can then run the task as a script. Execution of the task will pause at
the breakpoint.

```powershell
> ./mytask.ps1
```

📖 **Related information**
- [`Set-PSBreakpoint`
  documentation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/set-psbreakpoint?view=powershell-7)

### Task helper methods

Both the [Python task
helper](https://github.com/puppetlabs/puppetlabs-python_task_helper) and [Ruby
task helper](https://github.com/puppetlabs/puppetlabs-ruby_task_helper) include
methods that can help you debug a task. The `debug` method logs arbitrary values
as debugging messages, while the `debug_statements` method returns an array of
the logged debugging messages.

When a task using a task helper library raises a `TaskError`, the error will
include any logged debugging messages under the `details` key. You can also add
debugging statements when raising a `TaskError` yourself by calling
`debug_statements` and adding the result under the `details` key.

> 🔩 **Tip:** When running a task with `bolt task run`, use the `--format json`
> option to see the full result from the task, including the value of the
> `details` key.

#### Python tasks

The following Python task includes a few debugging statements which describe
what the task is doing and the results from a couple arithmetic operations:

**Metadata**

```json
{
  "files": ["python_task_helper/files/task_helper.py"]
}
```

**Task**

```python
#!/usr/bin/env python

import os, sys
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'python_task_helper', 'files'))
from task_helper import TaskHelper

class MyTask(TaskHelper):
    def task(self, args):
        self.debug('Adding values')
        sum = args['value_1'] + args['value_2']
        self.debug("Sum of values: {}".format(sum))

        self.debug('Dividing values')
        quotient = args['value_1'] / args['value_2']
        self.debug("Quotient of values: {}".format(quotient))

        return { 'sum': sum, 'quotient': quotient }

if __name__ == '__main__':
    MyTask().run()

```

**Output**

Running this task with the parameter `value_2=0` will raise a `TaskError`
that will automatically include the logged debugging statements under the
`details` key:

```shell
$ bolt task run mytask -t localhost value_1=10 value_2=0 --format json
{
  "items":[
    {
      "target":"localhost",
      "action":"task",
      "object":"mytask",
      "status":"failure",
      "value":{
        "_error":{
          "msg":"integer division or modulo by zero",
          "issue_code":"EXCEPTION",
          "kind":"python.task.helper/exception",
          "details":{
            "debug":[
              "Adding values",
              "Sum of values: 1",
              "Dividing values"
            ],
            "class":"ZeroDivisionError"
          }
        }
      }
    }
  ],
  "target_count":1,
  "elapsed_time":0
}
```

📖 **Related information**
- [Python task helper
  debugging](https://github.com/puppetlabs/puppetlabs-python_task_helper#debugging)

#### Ruby tasks

The following Ruby task includes a few debugging statements which describe
what the task is doing and the results from a couple arithmetic operations:

**Metadata**

```json
{
  "files": ["ruby_task_helper/lib/task_helper.rb"]
}
```

**Task**

```ruby
#!/usr/bin/env ruby

require_relative "../../ruby_task_helper/files/task_helper.rb"

class MyTask < TaskHelper
  def task(opts)
    debug 'Adding values'
    sum = opts[:value_1] + opts[:value_2]
    debug "Sum of values: #{sum}"

    debug 'Dividing values'
    quotient = opts[:value_1] / opts[:value_2]
    debug "Quotient of values: #{quotient}"

    { sum: sum, quotient: quotient }
  end
end

if __FILE__ == $0
  MyTask.run
end
```

**Output**

Running this task with the parameter `value_2=0` will raise a `TaskError`
that will automatically include the logged debugging statements under the
`details` key:

```shell
$ bolt task run mytask -t localhost value_1=10 value_2=0 --format json

{
  "items":[
    {
      "target":"localhost",
      "action":"task",
      "object":"mytask",
      "status":"failure",
      "value":{
        "_error":{
          "kind":"ZeroDivisionError",
          "msg":"divided by 0",
          "details":{
            "debug":[
              "Adding values",
              "Sum of values: 1",
              "Dividing values"
            ]
          }
        }
      }
    }
  ],
  "target_count":1,
  "elapsed_time":0
}
```       

📖 **Related information**
- [Ruby task helper
  debugging](https://github.com/puppetlabs/puppetlabs-ruby_task_helper#debugging)

### Running a task as a script

Running tasks without Bolt can make debugging easier, as the task will no
longer be executed in a separate thread. Since tasks are similar to scripts,
you can make temporary changes to the task so they can accept command-line
arguments and be run from the command line.

#### Python examples

Tasks that are written to accept input from `stdin` can already by run as
a script by piping the parameters as JSON to the task:

```python
#!/usr/bin/env python
import sys, json

params = json.load(sys.stdin)

result = {
    "sum": params['num1'] + params['num2']
}

print(json.dumps(result))
```

```shell
$ echo '{"num1":10,"num2":5}' | ./mytask.py
```

Alternatively, you can write your task to parse command-line arguments
as parameters if they are present:

```python
#!/usr/bin/env python
import sys, json

if len(sys.argv) > 0:
    params = {
        "num1": int(sys.argv[1]),
        "num2": int(sys.argv[2])
     }
else:
    params = json.load(sys.stdin)

result = {
    "sum": params['num1'] + params['num2']
}

print(json.dumps(result))
```

```shell
$ ./mytask.py 10 5
```

#### Ruby examples

Tasks that are written to accept input from `stdin` can already be run as
a script by piping the parameters as JSON to the task:

```ruby
#!/usr/bin/env ruby
require 'json'

params = JSON.parse(STDIN.read)

result = {
  'sum' => params['num1'] + params['num2']
}

puts result.to_json
```

```shell
$ echo '{"num1":10,"num2":5}' | ./mytask.rb
```

Alternatively, you can write your task to parse command-line arguments
as parameters if they are present:

```ruby
#!/usr/bin/env ruby
require 'json'

if ARGV.any?
  params = {
    'num1' => ARGV[0].to_i,
    'num2' => ARGV[1].to_i
  }
else
  params = JSON.parse(STDIN.read)
end

result = {
  'sum' => params['num1'] + params['num2']
}

puts result.to_json
```

```shell
$ ./mytask.rb 10 5
```

#### PowerShell example

Bolt sends parameters to PowerShell tasks by converting the parameters into
named arguments. You can run a PowerShell task as a script by running it
from the command line and providing the parameters as named arguments:

```powershell
[CmdletBinding()]
Param(
	[Int]$num1,
  [Int]$num2
)

$result = @{Sum=($num1 + $num2)} | ConvertTo-Json

Write-Output $result
```

```powershell
> ./mytask.ps1 -num1 10 -num2 5
```

### Redirecting `stderr`

By default, Bolt does not display output from `stderr` if any output is sent
to `stdout`. If you want to stream output from both `stderr` and `stdout`, you
can redirect `stderr`.

#### Python example

To redirect `stderr` to `stdout` in a Python task, use the `sys` library:

```python
import sys
sys.stderr = sys.stdout
```

#### Ruby example

To redirect `stderr` to `stdout` in a Ruby task, set the `$stderr` global
variable:

```ruby
$stderr = $stdout
```
