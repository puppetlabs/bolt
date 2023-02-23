# Task helpers

Bolt ships with several libraries that can be used to help write tasks.
These task helpers include functions for returning structured output,
creating error objects, and more. Because Bolt ships with these task
helpers, you do not need to install them separately.

The following task helpers are shipped with Bolt:

| Language | Module |
| --- | --- |
| Python | [python_task_helper](https://forge.puppet.com/modules/puppetlabs/python_task_helper) |
| Ruby | [ruby_task_helper](https://forge.puppet.com/modules/puppetlabs/ruby_task_helper) |
| Bash | [bash_task_helper](https://forge.puppet.com/modules/puppetlabs/bash_task_helper) |
| PowerShell | [powershell_task_helper](https://forge.puppet.com/modules/puppetlabs/powershell_task_helper) |

## Examples

### Python task helper

The following task uses the Python task helper to create a simple task that
outputs a greeting.

To use the Python task helper, include the
`python_task_helper/files/task_helper.py` file in the task metadata.

**Metadata**

```json
{
  "files": [
    "python_task_helper/files/task_helper.py"
  ],
  "input_method": "stdin",
  "parameters": {
    "name": {
      "description": "Name to use in greeting",
      "type": "String"
    }
  }
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

### Ruby task helper

The following task uses the Ruby task helper to create a simple task that
outputs a greeting.

To use the Ruby task helper, include the
`ruby_task_helper/files/task_helper.rb` file in the task metadata.

**Metadata**

```json
{
  "files": [
    "ruby_task_helper/files/task_helper.rb"
  ],
  "input_method": "stdin",
  "parameters": {
    "name": {
      "description": "Name to use in greeting",
      "type": "String"
    }
  }
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


### PowerShell task helper

The following task uses the PowerShell task helper to create a simple task that
outputs a greeting.

To use the PowerShell task helper, include the
`powershell_task_helper/files/BoltPwshHelper` file in the task metadata.

> **Note**: If you're using a version of PowerShell more recent than 3.0, you
  don't have to write an import statement to load the task helper. Bolt
  automatically loads the module by adding your task directory to
  `$env:PSModulePath`.

**Metadata**

```json
{
  "files": [
    "powershell_task_helper/files/BoltPwshHelper/"
  ],
  "input_method": "powershell",
  "parameters": {
    "name": {
      "description": "Name of user to run command",
      "type": "String"
    }
  }
}
```

**Task**

```powershell
#!/usr/bin/env pwsh
[CmdletBinding()]
Param(
  [Parameter(Mandatory = $True)]
  [String]
  $Name
)

<#
If using PowerShell 3.0, you will need to add an import statement here:
Import-Module BoltPwshHelper
#>
​
<#
Handle unhandled exceptions using the `trap` keyword
#>
trap {
  Write-BoltError -Message "Generic trap handler" -Exception $_
}

<#
A example of a custom error messages based on a specific use case
#>
if ($name -eq 'Robert') {
  Write-BoltError -Message "User ${name} not allowed"
}
else {
  # TODO
}

<#
An exmaple of returning a full exception stacktrace in Bolt formatted json
You can add a `-Message` if you want
#>
try {
  Write-Output (@{ "greeting" = "Hi, my name is ${name}"} | ConvertTo-JSON)
}
catch {
  Write-BoltError -Exception $_
}
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

### Bash task helper

The following task uses the Bash task helper to create a simple task that
outputs a greeting.

To use the Bash task helper, include the
`bash_task_helper/files/task_helper.sh` file in the task metadata.

**Metadata**

```json
{
  "files": [
    "bash_task_helper/files/task_helper.sh"
  ],
  "input_method": "environment",
  "parameters": {
    "name": {
      "description": "Name to use in greeting",
      "type": "String"
    }
  }
}
```

**Task**

```bash
#!/usr/bin/env bash

declare PT__installdir
source "$PT__installdir/bash_task_helper/files/task_helper.sh"

if [ "$PT_name" = "Robert" ]; then
  task-fail "You can't sit with us!"
fi

task-succeed "Hello, my name is $PT_name"
```

**Output**

```console
$ bolt task run mymodule::mytask -n localhost name="Adam"
Started on localhost...
Finished on localhost:
  {
    "greeting": "Hi, my name is Adam"
  }
Successful on 1 target: localhost
Ran on 1 target in 0.12 seconds
```
