# Writing tasks

Bolt tasks are similar to scripts, but they are kept in modules and can have metadata. This allows you to reuse and share them.

You can write tasks in any programming language the target nodes run, such as Bash, PowerShell, or Python. A task can even be a compiled binary that runs on the target. Place your task in the `./tasks` directory of a module and add a metadata file to describe parameters and configure task behavior.

For a task to run on remote \*nix systems, it must include a shebang \(`#!`\) line at the top of the file to specify the interpreter.

For example, the Puppet `mysql::sql` task is written in Ruby and provides the path to the Ruby interpreter. This example also accepts several parameters as JSON on `stdin` and returns an error.

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

## Secure coding practices for tasks

Use secure coding practices when you write tasks and help protect your system.

**Note:** The information in this topic covers basic coding practices for writing secure tasks. It is not an exhaustive list.

One of the methods attackers use to gain access to your systems is remote code execution, where by running an allowed script they gain access to other parts of the system and can make arbitrary changes. Because Bolt executes scripts across your infrastructure, it is important to be aware of certain vulnerabilities, and to code tasks in a way that guards against remote code execution.

Adding task metadata that validates input is one way to reduce vulnerability. When you require an enumerated \(`enum`\) or other non-string types, you prevent improper data from being entered. An arbitrary string parameter does not have this assurance.

For example, if your task has a parameter that selects from several operational modes that are passed to a shell command, instead of

```
String $mode = 'file'
```

use

```
Enum[file,directory,link,socket] $mode = file
```

If your task has a parameter that identifies a file on disk, ensure that a user can't specify a relative path that takes them into areas where they shouldn't be. Reject file names that have slashes.

Instead of

```
String $path
```

use

```
Pattern[/\A[^\/\\]*\z/] $path
```

In addition to these task restrictions, different scripting languages each have their own ways to validate user input.

### PowerShell

In PowerShell, code injection exploits calls that specifically evaluate code. Do not call `Invoke-Expression` or `Add-Type` with user input. These commands evaluate strings as C\# code.

Reading sensitive files or overwriting critical files can be less obvious. If you plan to allow users to specify a file name or path, use `Resolve-Path` to verify that the path doesn't go outside the locations you expect the task to access. Use `Split-Path -Parent $path` to check that the resolved path has the desired path as a parent.

For more information, see [PowerShell Scripting](https://docs.microsoft.com/en-us/powershell/scripting/PowerShell-Scripting?view=powershell-6) and [Powershell's Security Guiding Principles](https://blogs.msdn.microsoft.com/powershell/2008/09/30/powershells-security-guiding-principles/).

### Bash

In Bash and other command shells, shell command injection takes advantage of poor shell implementations. Put quotation marks around arguments to prevent the vulnerable shells from evaluating them.

Because the `eval` command evaluates all arguments with string substitution, avoid using it with user input; however you can use `eval` with sufficient quoting to prevent substituted variables from being executed.

Instead of

```shell script
eval "echo $input"
```

use

```shell script
eval "echo '$input'"
```

These are operating system-specific tools to validate file paths: `realpath` or `readlink -f`.

### Python

In Python malicious code can be introduced through commands like `eval`, `exec`, `os.system`, `os.popen`, and `subprocess.call` with `shell=True`. Use `subprocess.call` with `shell=False` when you include user input in a command or escape variables.

Instead of

```python
os.system('echo '+input)

```

use

```python
subprocess.check_output(['echo', input])
```

Resolve file paths with `os.realpath` and confirm them to be within another path by looping over `os.path.dirname` and comparing to the desired path.

For more information on the vulnerabilities of Python or how to escape variables, see Kevin London's blog post on [Dangerous Python Functions](https://www.kevinlondon.com/2015/07/26/dangerous-python-functions.html).

### Ruby

In Ruby, command injection is introduced through commands like `eval`, `exec`, `system`, backtick \(\`\`\) or `%x()` execution, or the Open3 module. You can safely call these functions with user input by passing the input as additional arguments instead of a single string.

Instead of

```ruby
system("echo #{flag1} #{flag2}")
```

use

```ruby
system('echo', flag1, flag2)
```

Resolve file paths with `Pathname#realpath`, and confirm them to be within another path by looping over `Pathname#parent` and comparing to the desired path.

For more information on securely passing user input, see the blog post [Stop using backtick to run shell command in Ruby](https://www.hilman.io/blog/2016/01/stop-using-backtick-to-run-shell-command-in-ruby/).

## Naming tasks

Task names are named based on the filename of the task, the name of the module, and the path to the task within the module.

You can write tasks in any language that runs on the target nodes. Give task files the extension for the language they are written in \(such as `.rb` for Ruby\), and place them in the top level of your module's `./tasks` directory.

Task names are composed of one or two name segments, indicating:

-   The name of the module where the task is located.
-   The name of the task file, without the extension.

For example, the `puppetlabs-mysql` module has the `sql` task in `./mysql/tasks/sql.rb`, so the task name is `mysql::sql`. This name is how you refer to the task when you run tasks.

The task filename `init` is special: the task it defines is referenced using the module name only. For example, in the `puppetlabs-service` module, the task defined in `init.rb` is the `service` task.

Each task or plan name segment must begin with a lowercase letter and:

-   Must start with a lowercase letter.
-   May include digits.
-   May include underscores.
-   Namespace segments must match the following regular expression `\A[a-z][a-z0-9_]*\Z`
-   The file extension must not use the reserved extensions .md or .json.

### Single-platform tasks

A task can consist of a single executable with or without a corresponding metadata file. For instance, `./mysql/tasks/sql.rb` and `./mysql/tasks/sql.json`. In this case, no other `./mysql/tasks/sql.*` files can exist.

### Cross-platform tasks

A task can have multiple implementations, with metadata that explains when to use each one. A primary use case for this is to support different implementations for different target platforms, referred to as cross-platform tasks.

For instance, consider a module with the following files:

```
- tasks
  - sql_linux.sh
  - sql_linux.json
  - sql_windows.ps1
  - sql_windows.json
  - sql.json
```

This task has two executables \(`sql_linux.sh` and `sql_windows.ps1`\), each with an implementation metadata file and a task metadata file. The executables have distinct names and are compatible with older task runners such as Puppet Enterprise 2018.1 and earlier. Each implementation has its own metadata that documents how to use the implementation directly or marks it as private to hide it from UI lists.

An implementation metadata example:

```json
{
  "name": "SQL Linux",
  "description": "A task to perform sql operations on linux targets",
  "private": true
}
```

The task metadata file contains an implementations section:

```json
{
  "implementations": [
    {"name": "sql_linux.sh", "requirements": ["shell"]},
    {"name": "sql_windows.ps1", "requirements": ["powershell"]}
  ]
}
```

Each implementations has a `name` and a list of `requirements`. The requirements are the set of *features* which must be available on the target in order for that implementation to be used. In this case, the `sql_linux.sh` implementation requires the `shell` feature, and the `sql_windows.ps1` implementations requires the PowerShell feature.

The set of features available on the target is determined by the task runner. You can specify additional features for a target via `set_feature` or by adding `features` in the inventory. The task runner chooses the *first* implementation whose requirements are satisfied.

The following features are defined by default:

-   `puppet-agent`: Present if the target has the Puppet agent package installed. This feature is automatically added to hosts with the name `localhost`.
-   `shell`: Present if the target has a posix shell.
-   `powershell`: Present if the target has PowerShell.

## Sharing executables

Multiple task implementations can refer to the same executable file.



Executables can access the `_task` metaparameter, which contains the task name. For example, the following creates the tasks `service::stop` and `service::start`, which live in the executable but appear as two separate tasks.

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

Multiple tasks can share common files between them. Tasks can additionally pull library code from other modules.

To create a task that includes additional files pulled from modules, include the files property in your metadata as an array of paths. A path consists of:

-   the module name
-   one of the following directories within the module:
    -   `files` — Most helper files. This prevents the file from being treated as a task or added to the Puppet Ruby loadpath.
    -   `tasks` — Helper files that can be called as tasks on their own.
    -   `lib` — Ruby code that might be reused by types, providers, or Puppet functions.
-   the remaining path to a file or directory; directories must include a trailing slash `/`

All path separators must be forward slashes. An example would be `stdlib/lib/puppet/`.

The `files` property can be included both as a top-level metadata property, and as a property of an implementation, for example:

```json
{
  "implementations": [
    {"name": "sql_linux.sh", "requirements": ["shell"], "files": ["mymodule/files/lib.sh"]},
    {"name": "sql_windows.ps1", "requirements": ["powershell"], "files": ["mymodule/files/lib.ps1"]}
  ],
  "files": ["emoji/files/emojis/"]
}
```

When a task includes the `files` property, all files listed in the top-level property and in the specific implementation chosen for a target are copied to a temporary directory on that target. The directory structure of the specified files is preserved such that paths specified with the `files` metadata option are available to tasks prefixed with `_installdir`. The task executable itself is located in its module location under the `_installdir` as well, so other files can be found at `../../mymodule/files/`relative to the task executable's location.

For example, you can create a task and metadata in a module at `~/.puppetlabs/bolt/site-modules/mymodule/tasks/task.{json,rb}`.

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
Successful on 1 node: localhost
Ran on 1 node in 0.12 seconds
```

### Task helpers

To help with writing tasks, Bolt includes [python_task_helper](https://github.com/puppetlabs/puppetlabs-python_task_helper) and [ruby_task_helper](https://github.com/puppetlabs/puppetlabs-ruby_task_helper). It also makes a useful demonstration of including code from another module.

### Python example

Create task and metadata in a module at `~/.puppetlabs/bolt/site-modules/mymodule/tasks/task.{json,py}`.

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
Successful on 1 node: localhost
Ran on 1 node in 0.12 seconds
```

### Ruby example

Create task and metadata in a new module at `~/.puppetlabs/bolt/site-modules/mymodule/tasks/mytask.{json,rb}`.

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

class MyTask < TaskHelper 
  def task(name: nil, **kwargs)
    { greeting: "Hi, my name is #{name}" }
  end
end


MyTask.run if __FILE__ == $0
```

**Output**

```console
$ bolt task run mymodule::mytask -n localhost name="Robert'); DROP TABLE Students;--"
Started on localhost...
Finished on localhost:
  {
    "greeting": "Hi, my name is Robert'); DROP TABLE Students;--"
  }
Successful on 1 node: localhost
Ran on 1 node in 0.12 seconds
```

## Writing remote tasks

Some targets are hard or impossible to execute tasks on directly. In these cases, you can write a task that runs on a proxy target and remotely interacts with the real target.

For example, a network device might have a limited shell environment or a cloud service might be driven only by HTTP APIs. By writing a remote task, Bolt allows you to specify connection information for remote targets in their inventory file and injects them into the `_target` metaparam.

This example shows how to write a task that posts messages to Slack and reads connection information from `inventory.yaml`:

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

To prevent accidentally running a normal task on a remote target and breaking its configuration, Bolt won't run a task on a remote target unless its metadata defines it as remote:

```json
{
  "remote": true
}
```

Add Slack as a remote target in your inventory file:

```yaml
nodes:
  - name: my_slack
    config:
      transport: remote
      remote:
        token: <SLACK_API_TOKEN>
```

Finally, make `my_slack` a target that can run the `slack::message`:

```shell script
bolt task run slack::message --nodes my_slack message="hello" channel=<slack channel id>
```

## Defining parameters in tasks

Allow your task to accept parameters as either environment variables or as a JSON hash on standard input.

Tasks can receive input as either environment variables, a JSON hash on standard input, or as PowerShell arguments. By default, the task runner submits parameters as both environment variables and as JSON on `stdin`.

If your task must receive parameters only in a certain way, such as only `stdin`, you can set the input method in your task metadata. For Windows tasks, it's usually better to use tasks written in PowerShell. See the related topic about task metadata for information about setting the input method.

Environment variables are the easiest way to implement parameters, and they work well for simple JSON types such as strings and numbers. For arrays and hashes, use structured input instead because parameters with undefined values \(`nil`, `undef`\) passed as environment variables have the `String` value `null`. For more information, see [Structured input and output](writing_tasks.md#).

To add parameters to your task as environment variables, pass the argument prefixed with the Puppet task prefix `PT_` .

For example, to add a `message` parameter to your task, read it from the environment in task code as `PT_message`. When the user runs the task, they can specify the value for the parameter on the command line as `message=hello`, and the task runner submits the value `hello` to the `PT_message` variable.

```shell script
#!/usr/bin/env bash
echo your message is $PT_message
```

### Defining parameters in Windows

For Windows tasks, you can pass parameters as environment variables, but it's easier to write your task in PowerShell and use named arguments. By default tasks with a `.ps1` extension use PowerShell standard argument handling.

For example, this PowerShell task takes a process name as an argument and returns information about the process. If no parameter is passed by the user, the task returns all of the processes.

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

To pass parameters in your task as environment variables \(`PT_parameter`\), you must set `input_method` in your task metadata to `environment`. To run Ruby tasks on Windows, the Puppet agent must be installed on the target nodes.

## Returning errors in tasks

To return a detailed error message if your task fails, include an `Error` object in the task's result.

When a task exits non-zero, the task runner checks for an error key \(\`_error\`\). If one is not present, the task runner generates a generic error and adds it to the result. If there is no text on `stdout` but text is present on `stderr`, the `stderr` text is included in the message.

```json
{ "_error": {
    "msg": "Task exited 1:\nSomething on stderr",
    "kind": "puppetlabs.tasks/task-error",
    "details": { "exitcode": 1 }
}
```

An error object includes the following keys:

-   **msg** - A human readable string that appears in the UI.
-   **kind** - A standard string for machines to handle. You may share kinds between your modules or namespace kinds per module.
-   **details** - An object of structured data about the tasks.

Tasks can provide more details about the failure by including their own error object in the result at `_error`.

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

## Structured input and output

If you have a task that has many options, returns a lot of information, or is part of a task plan, consider using structured input and output with your task.

The task API is based on JSON. Task parameters are encoded in JSON, and the task runner attempts to parse the output of the tasks as a JSON object.

The task runner can inject keys into that object, prefixed with `_`. If the task does not return a JSON object, the task runner creates one and places the output in an `_output` key.

### Structured input

For complex input, such as hashes and arrays, you can accept structured JSON in your task.

By default, the task runner passes task parameters as both environment variables and as a single JSON object on stdin. The JSON input allows the task to accept complex data structures.

To accept parameters as JSON on stdin, set the `params` key to accept JSON on `stdin`.

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

If your task accepts input on `stdin`, specify `"input_method": "stdin"` in the task's `metadata.json` file, or it might not work with sudo for some users.

### Returning structured output

To return structured data from your task, print only a single JSON object to `stdout` in your task.

Structured output is useful if you want to use the output in another program, or if you want to use the result of the task in a Puppet task plan.

```python
#!/usr/bin/env python

import json
import sys
minor = sys.version_info
result = { "major": sys.version_info.major, "minor": sys.version_info.minor }
json.dump(result, sys.stdout)
```

## Converting scripts to tasks

To convert an existing script to a task, you can either write a task that wraps the script or you can add logic in your script to check for parameters in environment variables.

If the script is already installed on the target nodes, you can write a task that wraps the script. In the task, read the script arguments as task parameters and call the script, passing the parameters as the arguments.

If the script isn't installed or you want to make it into a cohesive task so that you can manage its version with code management tools, add code to your script to check for the environment variables, prefixed with `PT_`, and read them instead of arguments.

CAUTION:

For any tasks that you intend to use with PE and assign RBAC permissions, make sure the script safely handles parameters or validate them to prevent shell injection vulnerabilities.

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

### Wrapping an existing script

If a script is not already installed on targets and you don't want to edit it, for example if it's a script someone else maintains, you can wrap the script in a small task without modifying it.

**CAUTION:** For any tasks that you intend to use with PE and assign RBAC permissions, makesure the script safely handles parameters or validate them to prevent shell injection vulnerabilities.

Given a script, `myscript.sh`, that accepts 2 positional args, `filename` and `version`:

1.  Copy the script to the module's `files/` directory.

2.  Create a metadata file for the task that includes the parameters and file dependency.

    ```json
    {
        "input_method": "environment",
        "parameters": {
            "filename": { "type": "String[1]" },
            "version": { "type": "String[1]" }
        },
        "files": [ "script_example/files/myscript.sh" ]
    }
    ```

3.  Create a small wrapper task that reads environment variables and calls the task.

    ```shell script
    #!/usr/bin/env bash
    set -e
    
    script_file="$PT__installdir/script_example/files/myscript.sh"
    # If this task is going to be run from windows nodes the wrapper must make sure it's exectutable
    chmod +x $script_file
    commandline=("$script_file" "$PT_filename" "$PT_version")
    # If the stderr output of the script is important redirect it to stdout.
    "${commandline[@]}" 2>&1
    ```


## Supporting no-op in tasks

Tasks support no-operation functionality, also known as no-op mode. This function shows what changes the task would make, without actually making those changes.

No-op support allows a user to pass the `--noop` flag with a command to test whether the task will succeed on all targets before making changes.

To support no-op, your task must include code that looks for the `_noop` metaparameter. No-op is supported only in Puppet Enterprise.

If the user passes the `--noop` flag with their command, this parameter is set to `true`, and your task must not make changes. You must also set `supports_noop` to `true` in your task metadata or the task runner will refuse to run the task in noop mode.

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

## Task metadata

Task metadata files describe task parameters, validate input, and control how the task runner executes the task.

Your task must have metadata to be published and shared on the Forge. Specify task metadata in a JSON file with the naming convention `<TASKNAME>.json` . Place this file in the module's `./tasks` folder along with your task file.

For example, the module `puppetlabs-mysql` includes the `mysql::sql` task with the metadata file, `sql.json`.

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

### Adding parameters to metadata

To document and validate task parameters, add the parameters to the task metadata as JSON object, `parameters`.

If a task includes `parameters` in its metadata, the task runner rejects any parameters input to the task that aren't defined in the metadata.

In the `parameter` object, give each parameter a description and specify its Puppet type. For a complete list of types, see the [types documentation](https://docs.puppet.com/puppet/latest/lang_data_type.html).

For example, the following code in a metadata file describes a `provider` parameter:

```json
"provider": {
  "description": "The provider to use to manage or inspect the service, defaults to the system service manager",
  "type": "Optional[String[1]]"
 }
```

#### Define sensitive parameters

You can define task parameters as sensitive, for example, passwords and API keys. These values are masked when they appear in logs and API responses. When you want to view these values, set the log file to `level: debug`.

To define a parameter as sensitive within the JSON metadata, add the `"sensitive": true` property.

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

### Task metadata reference

The following table shows task metadata keys, values, and default values.

#### **Task metadata**

|Metadata key|Description|Value|Default|
|------------|-----------|-----|-------|
|"description"|A description of what the task does.|String|None|
|"input_method"|What input method the task runner uses to pass parameters to the task.|-   `environment`<br/>- `stdin`<br/>- `powershell`|Both `environment` and `stdin` unless `.ps1` tasks, in which case `powershell`|
|"parameters"|The parameters or input the task accepts listed with a puppet type string and optional description. See [adding parameters to metadata](writing_tasks.md#) for usage information.|Array of objects describing each parameter|None|
|"puppet_task_version"|The version of the spec used.|Integer|`1` \(This is the only valid value.\)|
|"supports_noop"|Whether the task supports no-op mode. Required for the task to accept the `--noop` option on the command line.|Boolean|`false`|
|"implementations"|A list of task implementations and the requirements used to select one to run. See [Cross-platform tasks](writing_tasks.md#) for usage information.|Array of Objects describing each implementation|None|
|"files"|A list of files to be provided when running the task, addressed by module. See [Sharing task code](writing_tasks.md#) for usage information.|Array of Strings|None|
|"private"|Do not display task by default when listing for UI.|Boolean|`false`|
|"remote"|Whether this task is allowed to run on a proxy target, from which it will interact with a remote target. Remote tasks must not change state locally when the `_targets` meta parameter is set.|Boolean|`false`|

### Task metadata types

Task metadata can accept most Puppet data types.

#### Common task data types

**Restriction:**

Some types supported by Puppet can not be represented as JSON, such as `Hash[Integer, String]`, `Object`, or `Resource`. Do not use these in tasks, because they can never be matched.

|Type|Description|
|----|-----------|
|`String`|Accepts any string.|
|`String[1]`|Accepts any non-empty string \(a String of at least length 1\).|
|`Enum[choice1, choice2]`|Accepts one of the listed choices.|
|`Pattern[/\A\w+\Z/]`|Accepts Strings matching the regex `/\w+/` or non-empty strings of word characters.|
|`Integer`|Accepts integer values. JSON has no Integer type so this can vary depending on input.|
|`Optional[String[1]]`|Optional makes the parameter optional and permits null values. Tasks have no required nullable values.|
|`Array[String]`|Matches an array of strings.|
|`Hash`|Matches a JSON object.|
|`Variant[Integer, Pattern[/\A\d+\Z/]]`|Matches an integer or a String of an integer|
|`Boolean`|Accepts Boolean values.|

**Related information**  

[Data type syntax](https://puppet.com/docs/puppet/latest/lang_data_type.html)

## Specifying parameters

Parameters for tasks can be passed to the `bolt` command as CLI arguments or as a JSON hash.

To pass parameters individually to your task or plan, specify the parameter value on the command line in the format `<PARAMETER>=<VALUE>`. Pass multiple parameters as a space-separated list. Bolt attempts to parse each parameter value as JSON and compares that to the parameter type specified by the task or plan. If the parsed value matches the type, it is used; otherwise, the original string is used.

For example, to run the `mysql::sql` task to show tables from a database called `mydatabase`:

```shell script
bolt task run mysql::sql database=mydatabase sql="SHOW TABLES" --nodes neptune --modules ~/modules
```

To pass a string value that is valid JSON to a parameter that would accept both quote the string. For example to pass the string `true` to a parameter of type `Variant[String, Boolean]` use `'foo="true"'`. To pass a String value wrapped in `"` quote and escape it `'string="\"val\"'`. Alternatively, you can specify parameters as a single JSON object with the `--params` flag, passing either a JSON object or a path to a parameter file.

To specify parameters as JSON, use the parameters flag followed by the JSON:
 
```
--params '{"name": "openssl"}'`
```

To set parameters in a file, specify parameters in JSON format in a file, such as `params.json`. For example, create a `params.json` file that contains the following JSON:

```json
{
  "name":"openssl"
}
```

Then specify the path to that file \(starting with an at symbol, `@`\) on the command line with the parameters flag: `--params @params.json`
