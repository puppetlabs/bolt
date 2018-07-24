
# Writing tasks

Tasks are similar to scripts, but they are kept in modules and can have
metadata. This allows you to reuse and share them more easily.

> Note: This information about writing tasks applies for both Puppet Enterprise
> and Bolt.

You can write tasks in any programming language the target nodes
will run, such as Bash, PowerShell, or Python. A task can even be a compiled binary that will run on the target.
Place your task in the ./tasks
directory of a module and add a metadata file to describe parameters and
configure task behavior.

For a task to run on remote *nix systems, it must include a shebang (`#!`) line
at the top of the file to specify the interpreter.

For example, the Puppet `mysql::sql` task is written in Ruby and provides the
path to the Ruby interpreter. This example also accepts several parameters as
JSON on stdin and returns an error.

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


## Secure Coding Practices for Tasks

Use secure coding practices when you write tasks and help protect your system.

> Note: The information in this topic covers basic coding practices for writing
> secure tasks. It is not an exhaustive list.

One of the methods attackers use to gain access to your systems is remote code
execution, where by running an allowed script they gain access to other parts
of the system and can make arbitrary changes. Because Puppet Bolt executes
scripts across your infrastructure, it is important to be aware of certain
vulnerabilities, and to code tasks in a way that guards against remote code
execution.

Adding task metadata that validates input is one way to reduce vulnerability.
When you require an enumerated (`enum`) or other non-string types, you prevent
improper data from being entered. An arbitrary string parameter does not have
this assurance.

For example, if your task has a parameter that selects from several operational
modes that will be passed to a shell command, instead of


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


## PowerShell

In PowerShell, code injection exploits calls that specifically evaluate code.
Do not call `Invoke-Expression` or `Add-Type` with user input. These commands
evaluate strings as C# code.

Reading sensitive files or overwriting critical files can be less obvious. If
you plan to allow users to specify a file name or path, use `Resolve-Path` to
verify that the path doesn't go outside the locations you expect the task to
access. Use `Split-Path -Parent $path` to check that the resolved path has the
desired path as a parent.

For more information, see PowerShell Scripting and Powershell's Security
Guiding Principles.


## Bash

In Bash and other command shells, shell command injection takes advantage of
poor shell implementations. Put quotations marks around arguments to prevent
the vulnerable shells from evaluating them.

Because the eval command will evaluate all arguments with string substitution,
you should avoid using it with user input; however you can use eval with
sufficient quoting to prevent substituted variables from being executed.

Instead of

```
eval "echo $input"
```

use

```
eval "echo '$input'"
```

These are operating system-specific tools to validate file paths: `realpath` or
`readlink -f`.


## Python

In Python malicious code can be introduced through commands like `eval`,
`exec`, `os.system`, `os.popen`, and `subprocess.call` with `shell=True`. Use
`subprocess.call` with `shell=False` when you include user input in a command
or escape variables.

Instead of


```
os.system('echo '+input)
```

use

```
subprocess.check_output(['echo', input])
```

Resolve file paths with `os.realpath` and confirm them to be within another path
by looping over `os.path.dirname` and comparing to the desired path.

For more information on the vulnerabilities of Python or how to escape
variables, see Kevin London's blog post on Dangerous Python Functions.


## Ruby

In Ruby, command injection is introduced through commands like `eval`, `exec`,
`system`, backtick (``) or `%x()` execution, or the `Open3` module. You can safely
call these functions with user input by passing the input as additional
arguments instead of a single string.

Instead of

```
system("echo #{flag1} #{flag2}")
```

use

```
system('echo', flag1, flag2)
```

Resolve file paths with `Pathname#realpath`, and confirm them to be within
another path by looping over `Pathname#parent` and comparing to the desired path.

For more information on securely passing user input, see the blog post Stop
using backtick to run shell command in Ruby.


## Naming tasks

Task names are named based on the filename of the task, the name of the module,
and the path to the task within the module.

You can write tasks in any language that will run on the target nodes. Give
task files the extension for the language they are written in (such as `.rb` for
Ruby), and place them in the top level of your module's `./tasks` directory.

Task names are composed of one or two name segments, indicating:

- The name of the module the task is located in.
- The name of the task file, without the extension.

For example, the `puppetlabs-mysql` module has the `sql` task in
`./mysql/tasks/sql.rb`, so the task name is `mysql::sql`. This name
is how you refer to the task when you run tasks.

The task filename `init` is special: the task it defines is referenced using the
module name only. For example, in the `puppetlabs-service` module, the task
defined in `init.rb` is the `service` task.

Each task or plan name segment must begin with a lowercase letter and:

- Must start with a lowercase letter.
- May include digits.
- May include underscores.
- Namespace segments must match the following regular expression \A[a-z][a-z0-9_]*\Z
- The file extension must not use the reserved extensions .md or .json.

### Tasks with a single implementation

A task can consist of a single executable with or without a corresponding metadata file. For
instance, `./mysql/tasks/sql.rb` and `./mysql/tasks/sql.json`. In this case, no
other `./mysql/tasks/sql.*` files can exist.

### Tasks with multiple implementations

A task can also have multiple implementation, with metadata that explains when
to use each implementation. For instance, consider a module with the following
files:

```
- tasks
  - sql.sh
  - sql.ps1
  - sql.json
```

This task has two executables (`sql.sh` and `sql.ps1`) with a metadata file. The metadata file contains an `implementations` section:

```json
{
  "implementations": [
    {"name": "sql.sh", "requirements": ["shell"]},
    {"name": "sql.ps1", "requirements": ["powershell"]}
  ]
}
```

Each implementations has a `name` and a list of `requirements`. The
requirements are the set of *features* which must be available on the target in
order for that implementation to be used. In this case, the `sql.sh`
implementation requires the `shell` feature, and the `sql.ps1` implementations
requires the `powershell` feature.

The set of features available on the target is determined by the task runner.
Additional features can be specified for a target via `set_feature`, or by
adding `features` in the inventory. The task runner will choose the *first*
implementation whose requirements are satisfied.

The following features are defined by default:
* `puppet-agent`: present if the target has the puppet agent package installed
* `shell`: present if the target has a posix shell
* `powershell`: present if the target has powershell

### Sharing executables

Multiple task implementations can refer to the same executable file. Executables can access the `_task` metaparam, which contains the task name.

For example, the following creates 2 tasks `service::stop` and `service::start`, which can live in the executable but appear as 2 separate tasks.

`myservice/tasks/init.rb`
```ruby
#!/usr/bin/env ruby
require 'json'

params = JSON.parse(STDIN.read)
action = params['action'] || params['_task']
if ['start',  'stop'].include?(action)
  `systemctl #{params['_task']} #{params['service']}`
end
```

`myservice/tasks/start.json`
```
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

`myservice/tasks/stop.json`
```
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


## Defining parameters in tasks

Allow your task to accept parameters as either environment variables or as a JSON hash
on standard input.

Tasks can receive input as either environment variables, a JSON hash on
standard input, or as PowerShell arguments. By default, the task runner submits
parameters as both environment variables and as JSON on stdin.

If your task should receive parameters only in a certain way, such as stdin
only, you can set the input method in your task metadata. For Windows tasks,
it's usually better to use tasks written in PowerShell. See the related topic
about task metadata for information about setting the input method.

Environment variables are the easiest way to implement parameters, and they
work well for simple JSON types such as strings and numbers. For arrays and
hashes, use structured input instead. See the related topic about structured
input and output for more information.

To add parameters to your task as environment variables, pass the argument
prefixed with the Puppet task prefix `PT_`.

For example, to add a message parameter to your task, read it from the environment in task code
as `PT_message`. When the user runs the task, they can specify the value for the
parameter on the command line as `message=hello`, and the task runner submits
the value hello to the `PT_message` variable.

```
#!/usr/bin/env bash
echo your message is $PT_message
```

### Defining parameters in Windows

For Windows tasks, you can pass parameters as environment variables, but it's
easier to write your task in PowerShell and use named arguments.
By default tasks with a `.ps1` extension use  PowerShell standard argument handling.

For example, this PowerShell task takes a process name as an argument and
returns information about the process. If no parameter is passed by the user,
the task returns all of the processes.

```
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
must set `input_method` in your task metadata to `environment`. To run Ruby tasks
on Windows, the Puppet agent must be installed on the target nodes.

## Returning errors in tasks

To return a detailed error message if your task fails, include an Error object
in the task's result.

When a task exits non-zero, the task runner checks for an error key (`_error`).
If one is not present, the task runner generates a generic error and adds
it to the result. If there is no text on `stdout` but text is present on `stderr`,
the `stderr` text is included in the message.


```
{ "_error": {
    "msg": "Task exited 1:\nSomething on stderr",
    "kind": "puppetlabs.tasks/task-error",
    "details": { "exitcode": 1 }
}
```

An error object includes the following keys:

- `msg`
  A human readable string that appears in the UI.
- `kind`
  A standard string for machines to handle. You may share kinds between your modules or namespace kinds per module.
- `details`
  An object of structured data about the tasks.

Tasks can provide more details about the failure by including their own error
object in the result at `_error`.

```
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

If you have a task that has many options, returns a lot of information, or is
part of a task plan, you might want to use structured input and output with
your task.

The task API is based on JSON. Task parameters are encoded in JSON, and the
task runner attempts to parse the output of the tasks as a JSON object.

The task runner can inject keys into that object, prefixed with `_`. If the task
does not return a JSON object, the task runner creates one and places the
output in an `_output` key.


### Structured input

For more complex input, such as hashes and arrays, you can accept structured
JSON in your task.

By default, the task runner passes task parameters as both environment
variables and as a single JSON object on `stdin`. The JSON input allows the task
to accept more complex data structures.

To accept parameters as JSON on stdin, set the params key to accept JSON on
stdin.

```
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

If your task accepts input on stdin it should specify `"input_method": "stdin"`
in its metadata.json or it may not work with sudo for some users.

### Returning structured output

To return structured data from your task, print only a single JSON object to
`stdout` in your task.

Structured output is useful if you want to use the output in another program,
or if you want to use the result of the task in a Puppet task plan.

```
#!/usr/bin/env python
import json
import sys
minor = sys.version_info
result = { "major": sys.version_info.major, "minor": sys.version_info.minor }
json.dump(result, sys.stdout)
```

## Converting scripts to tasks

To convert an existing script to a task, you can either write a task that wraps
the script or you can add logic in your script to check for parameters in environment
variables.

If the script is already installed on the target nodes, you can write a task
that wraps the script. In the task, read the script arguments as task
parameters and call the script, passing the parameters as the arguments.

If the script isn't installed or you want to make it into a cohesive task that
you can manage its version with code management tools, add code to your script
to check for the environment variables, prefixed with `PT_`, and read them
instead of arguments.

Given a script that accepts positional arguments on the command line:

```
version=$1
[ -z "$version" ] && echo "Must specify a version to deploy && exit 1

if [ -z "$2" ]; then
  filename=$2
else
  filename=~/myfile
fi
```
To convert the script into a task, replace this logic with task variables:

```
version=$PT_version #no need to validate if we use metadata
if [ -z "$PT_filename" ]; then
  filename=$PT_filename
else
  filename=~/myfile
fi
```

## Supporting no-op in tasks

Tasks can support no-operation functionality, also known as no-op mode. This
function shows what changes the task would make, without actually making those
changes.

No-op support allows a user to pass the `--noop` flag with a command to quickly
test whether the task will succeed on all targets before making changes.

To support no-op, your task must include code that looks for the `_noop`
metaparameter. No-op is supported only in Puppet Enterprise.

If the user passes the `--noop` flag with their command, this parameter is set to
`true`, and your task must not make changes. You must also set `supports_noop` to
`true` in your task metadata or the task runner will refuse to run the task in noop mode.


### No-op metadata example

```
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
```

}

### No-op task example

```
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

Task metadata files describe task parameters, validate input, and control how
the task runner executes the task.

Your task must have metadata to be published and shared on the Forge. Specify
task metadata in a JSON file with the naming convention `<TASKNAME>.json`. Place
this file in the module's `./tasks` folder along with your task file.

For example, the module `puppetlabs-mysql` includes the `mysql::sql` task with
the metadata file, `sql.json`.

```
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
      "type": "Optional[String[1]]"
    },
     "sql": {
      "description": "The SQL you want to execute",
      "type": "String[1]"
    }
  }
}
```


### Adding parameters to metadata

To document and validate task parameters, add the parameters to the task's
metadata as JSON object, parameters.

If a task includes parameters in its metadata, the task runner rejects any parameters input
to the task which aren't defined in the metadata.

In the parameter object, give each parameter a description and specify its
Puppet type. For a complete list of types, see the types documentation.

For example, the following code in a metadata file describes a provider parameter:

```
"provider": {
  "description": "The provider to use to manage or inspect the service, defaults to the system service manager",
  "type": "Optional[String[1]]"
 }
```


### Task metadata reference

The following table shows task metadata keys, values, and default values.

Task metadata
Metadata key	Description	Value	Default
- `"description"`
  A description of what the task does.
  Type: String.
  default: None.
- `"puppet_task_version"`
   The version of the spec used.
   Type Integer
   default 1 (This is the only valid value.)
- `"supports_noop"`
  Whether the task supports no-op mode. Required for the task to accept the `--noop` option on the command line.
  Type: Boolean.
  default: False.
- `"input_method"`
  What input method the task runner should use to pass parameters to the task.
  Type: environment, stdin, powershell
  default both environment and stdin for .ps1 tasks, powershell

- `"parameters"`
  The parameters or input the task accepts listed with a puppet type string and
  optional description. See adding parameters to metadata for usage
  information.	String specifying the Puppet data type
  Type: String describing the parameter
  default None.

### Task metadata types

Task metadata can accept most Puppet data types. The following table shows the
most commonly used types for tasks.

#### Common task data types

For a complete list of available types, see the types documentation.

> Restriction: Some types supported by Puppet can not be represented as JSON,
> such as `Hash[Integer, String]`, `Object`, or `Resource`. These should not be
> used in tasks, because they can never be matched.

Type	Description
- `String`	Accepts any string.
- `String[1]`	Accepts any non-empty string (a String of at least length 1).
- `Enum[choice1, choice2]`	Accepts one of the listed choices.
- `Pattern[/\A\w+\Z/]`	Accepts Strings matching the regex /\w+/ or non-empty strings of word characters.
- `Integer`	Accepts integer values. JSON has no Integer type so this can vary depending on input.
- `Optional[String[1]]`	Optional makes the parameter optional and permits null values. Tasks have no required nullable values.
- `Array[String]`	Matches an array of strings.
- `Hash`	Matches a JSON object.
- `Variant[Integer, Pattern[/\A\d+\Z/]]`	Matches an integer or a String of an integer
- `Boolean` Accepts boolean values.
