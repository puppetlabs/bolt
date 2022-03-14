# JSON output

Bolt output can be returned as JSON by specifying the `--format json`
command-line option or the `-Format json` parameter in PowerShell. Bolt commands
return JSON output guaranteed to have the following structures:

## `apply`

This command outputs an array of objects. Each object uses the following keys:

- `action` (string):
  The type of action that was executed. This value is always `apply`.

- `object` (null):
  This value is always `null`.

- `status` (string):
  Whether the apply completed successfully. This value is `success` if the apply
  is successful and `failure` otherwise.

- `target` (string):
  The name of the target that the apply ran on.

- `value` (object):
  The value returned by the apply.

  - `_output` (string):
    A summary of the resources changed during the apply.

  - `report` (object):
    A report from the reply. This is a serialized representation of the
    [`Puppet::Transaction::Report`
    object](https://puppet.com/docs/puppet/latest/format_report.html#format_report-puppet-transaction-report).

For example:

```json
[
  {
    "target": "nix",
    "action": "apply",
    "object": null,
    "status": "success",
    "value": {
      "report": {
        ...
      },
      "_output": "changed: 0, failed: 0, unchanged: 0 skipped: 0, noop: 0"
    }
  }
]
```

## `command run`

This command outputs an object. It uses the following keys:

- `elapsed_time` (number):
  The time, in seconds, that it took for the command to run on all targets.

- `items` (array of objects):
  A list of objects describing the result of running the command on each target.

  - `action` (string):
    The type of action that was executed. This value is always `command`.

  - `object` (string):
    The command that was run on the target.

  - `status` (string):
    Whether the command was successful. This value is `success` if the command
    was successful and `failure` otherwise.

  - `target` (string):
    The name of the target that the command was run on.

  - `value` (object):
    The command's output and exit code.

    - `exit_code` (number):
      The exit code returned by the command.

    - `merged_output` (string):
      The merged output from `stderr` and `stdout`. Output is merged in the
      order that Bolt receives it, which may be different from how it was
      output on the target itself.

    - `stderr` (string):
      Output written to `stderr`.

    - `stdout` (string):
      Output written to `stdout`.

- `target_count` (number):
  The number of targets that the command was run on.

For example:

```json
{
  "items": [
    {
      "target": "localhost",
      "action": "command",
      "object": "echo hello && echo goodbye 1>&2",
      "status": "success",
      "value": {
        "stdout": "hello\n",
        "stderr": "goodbye\n",
        "merged_output": "hello\ngoodbye\n",
        "exit_code": 0
      }
    }
  ],
  "target_count": 1,
  "elapsed_time": 0
}
```

## `file download`

This command outputs an object. It uses the following keys:

- `elapsed_time` (number):
  The total time, in seconds, that it took to download the file from all targets.

- `items` (array of objects):
  The results of downloading the file from each target.

  - `action` (string):
    The type of action that was executed. This value is always `download`.

  - `object` (string):
    The path to the file on the target.

  - `status` (string):
    Whether the download completed successfully. This value is `success` if the
    download is successful and `failure` otherwise.

  - `value` (object):
    The value returned by the download.

    - `_output` (string):
      A human-readable message describing where the file was downloaded to on the
      controller.

    - `path` (string):
      The path to the downloaded file on the controller.

- `target_count` (number):
  The number of targets the file was downloaded from.

For example:

```json
{
  "items": [
    {
      "target": "nix",
      "action": "download",
      "object": "/etc/ssh/sshd_config",
      "status": "success",
      "value": {
        "path": "/Users/bolt/.puppetlabs/bolt/downloads/nix/sshd_config",
        "_output": "Downloaded 'nix:/etc/ssh/sshd_config' to '/Users/bolt/.puppetlabs/bolt/downloads/nix'"
      }
    }
  ],
  "target_count": 1,
  "elapsed_time": 1
}
```

## `file upload`

This command outputs an object. It uses the following keys:

- `elapsed_time` (number):
  The total time, in seconds, that it took to upload the file to all targets.

- `items` (array of objects):
  The results of uploading the file to each target.

  - `action` (string):
    The type of action that was executed. This value is always `upload`.

  - `object` (string):
    The path to the file on the controller.

  - `status` (string):
    Whether the upload completed successfully. This value is `success` if the
    upload is successful and `failure` otherwise.

  - `value` (object):
    The value returned by the upload.

    - `_output` (string):
      A human-readable message describing where the file was uploaded to on the
      target.

- `target_count` (number):
  The number of targets the file was uploaded to.

For example:

```json
{
  "items": [
    {
      "target": "nix",
      "action": "upload",
      "object": "files/configure.sh",
      "status": "success",
      "value": {
        "_output": "Uploaded 'files/configure.sh' to 'nix:./configure.sh'"
      }
    }
  ],
  "target_count": 1,
  "elapsed_time": 1
}

```

## `group show`

This command outputs an object. It uses the following keys:

- `count` (number):
  The number of groups in the inventory.

- `groups` (array of strings):
  The names of all groups in the inventory.

For example:

```json
{
  "count": 3,
  "groups": [
    "all",
    "linux",
    "windows"
  ]
}
```

## `guide`

This command outputs an object. It uses the following key:

- `topics` (array of strings):
  The list of available topics.

For example:

```json
{
  "topics": [
    "inventory",
    "logging",
    "module"
  ]
}
```

## `guide <topic>`

This command outputs an object. It uses the following key:

- `guide` (string):
  The guide contents.

- `topic` (string):
  The topic the guide covers.

For example:

```json
{
  "guide": "A guide about projects.",
  "topic": "project",
}
```

## `inventory show`

This command outputs an object. It uses the following keys:

- `adhoc` (object):
  A list and count of adhoc targets. Adhoc targets are those that are not found
  in the inventory and are specified from the command line.

  - `count` (number):
    The number of adhoc targets.

  - `targets` (array of strings):
    The names of the adhoc targets.

- `count` (number):
  The total number of targets. Includes both adhoc and inventory targets.

- `inventory` (object):
  A list and count of inventory targets.

  - `count` (number):
    The number of inventory targets.

  - `file` (string):
    The path to the inventory file.

  - `targets` (array of strings):
    The names of the inventory targets.

- `targets` (array of strings):
  The names of all targets. Includes both adhoc and inventory targets.

For example:

```json
{
  "inventory": {
    "targets": [
      "nix",
      "win"
    ],
    "count": 2,
    "file": "/Users/bolt/.puppetlabs/bolt/inventory.yaml"
  },
  "adhoc": {
    "targets": [
      "adhoc"
    ],
    "count": 1
  },
  "targets": [
    "adhoc",
    "nix",
    "win"
  ],
  "count": 3
}
```

## `inventory show --detail`

This command outputs an object. It uses the following keys:

- `count` (number):
  The total number of targets.

- `targets` (array of objects):
  The detailed configuration and data for all targets.

  - `alias` (array of strings):
    The target's aliases.

  - `config` (object):
    The target's fully-resolved transport configuration. See the [transport
    configuration reference](bolt_transports_reference.md) for more information
    about available keys.

  - `facts` (object):
    The target's facts.

  - `features` (array of strings):
    The target's features.

  - `groups` (array of strings):
    The inventory groups that the target is included in.

  - `name` (string):
    The target's human-readable name.

  - `plugin_hooks` (object):
    The target's [plugin hooks](writing_plugins.md#plugin-hooks).

  - `uri` (string):
    The target's URI.

  - `vars` (object):
    The target's variables.

For example:

```json
{
  "targets": [
    {
      "name": "webserver",
      "uri": "webserver.example.org",
      "alias": [
        "server"
      ],
      "config": {
        "transport": "ssh",
        "ssh": {
          "cleanup": false,
          "connect-timeout": 10,
          "disconnect-timeout": 5,
          "load-config": true,
          "login-shell": "bash",
          "tty": false,
          "host-key-check": false
        }
      },
      "vars": {
        "timeout": 30
      },
      "features": [
        "puppet-agent"
      ],
      "facts": {
        "role": "webserver"
      },
      "plugin_hooks": {
        "puppet_library": {
          "plugin": "puppet_agent",
          "stop_service": true
        }
      },
      "groups": [
        "servers",
        "all"
      ]
    }
  ],
  "count": 1
}
```

## `lookup`

This command outputs an array of objects. Each object uses the following keys:

- `action` (string):
  The type of action that was executed. This value is always `lookup`.

- `object` (string):
  The lookup key.

- `status` (string):
  Whether the lookup completed successfully. This value is `success` if the
  lookup is successful and `failure` otherwise.

- `target` (string):
  The name of the target used as the context for the lookup.

- `value` (object):
  The value returned by the lookup.

  - `value` (string):
    The value returned by the lookup.

For example:

```json
[
  {
    "action": "lookup",
    "object": "password",
    "status": "success",
    "target": "webserver",
    "value": {
      "value": "Bolt!"
    }
  }
]
```

## `module add`

This command outputs an object. It uses the following keys:

- `moduledir` (string):
  The path to the directory that the module was installed to.

- `puppetfile` (string):
  The path to the project's Puppetfile.

- `success` (boolean):
  Whether the module was added successfully.

For example:

```json
{
  "success": true,
  "puppetfile": "/Users/bolt/.puppetlabs/bolt/Puppetfile",
  "moduledir": "/Users/bolt/.puppetlabs/bolt/.modules"
}
```

## `module generate-types`

This command does not provide JSON output.

## `module install`

This command outputs an object. It uses the following keys:

- `moduledir` (string):
  The path to the directory that the modules are installed to.

- `puppetfile` (string):
  The path to the project's Puppetfile.

- `success` (boolean):
  Whether the modules were installed successfully.

For example:

```json
{
  "success": true,
  "puppetfile": "/Users/bolt/.puppetlabs/bolt/Puppetfile",
  "moduledir": "/Users/bolt/.puppetlabs/bolt/.modules"
}
```

## `module show`

This command outputs an object. Each key in the object is the path to a
directory on the modulepath, and each value is an array of objects
describing each module in the directory.

- `<module directory>` (array of objects):
  The modules in the module directory.

  - `internal_module_group` (string):
    The name of the internal module group. For built-in modules, this is _Plan
    Language Modules_. For modules that ship with Bolt packages, this is
    _Packaged Modules_. For modules installed to the project's managed module
    directory (`.modules/`), this is _Project Dependencies_.

  - `name` (string):
    The name of the module.

  - `version` (string):
    The semantic version of the module.

For example:

```json
{
  "/opt/puppetlabs/bolt/lib/ruby/gems/2.7.0/gems/bolt-3.7.0/bolt-modules": [
    {
      "name": "boltlib",
      "version": null,
      "internal_module_group": "Plan Language Modules"
    }
  ],
  "/Users/bolt/.puppetlabs/bolt/.modules": [
    {
      "name": "puppetlabs/puppetdb",
      "version": "7.8.0",
      "internal_module_group": "Project Dependencies"
    }
  ],
  "/opt/puppetlabs/bolt/lib/ruby/gems/2.7.0/gems/bolt-3.7.0/modules": [
    {
      "name": "puppetlabs/yaml",
      "version": "0.2.0",
      "internal_module_group": "Packaged Modules"
    }
  ]
}
```

## `plan convert`

This command does not provide JSON output.

## `plan new`

This command does not provide JSON output.

## `plan run`

This command outputs a serialized representation of the [plan
result](https://puppet.com/docs/bolt/latest/bolt_types_reference.html#planresult).

## `plan show`

This command outputs an object. It uses the following keys:

- `modulepath` (array of strings):
  The project's modulepath.

- `plans` (array of arrays):
  A list of plan names and descriptions. Each item in the array is an array,
  where the first item is the plan's name and the second item is the plan's
  description.

For example:

```json
{
  "modulepath": [
    "/Users/bolt/.puppetlabs/bolt/modules",
    "/Users/bolt/.puppetlabs/bolt/.modules"
  ],
  "tasks": [
    [
      "facts",
      "A plan that retrieves facts and stores in the inventory for the\nspecified targets."
    ],
    [
      "reboot",
      "Reboots targets and waits for them to be available again."
    ]
  ]
}
```

## `plan show <plan>`

This command outputs an object. It uses the following keys:

- `description` (string):
  The plan's description.

- `module_dir` (string):
  The path to the plan's module.

- `name` (string):
  The plan's name.

- `parameters` (object)
  The plan's parameters. Each key is the name of the parameter and the value is
  an object that describes the parameter.
  
  - `default_value` (string):
    The parameter's default value.

  - `description` (string):
    The parameter's description.

  - `sensitive` (boolean):
    Whether the parameter is sensitive.

  - `type` (string):
    The parameter's type.

For example:

```json
{
  "name": "facts",
  "description": "A plan that retrieves facts and stores in the inventory for the\nspecified targets.",
  "parameters": {
    "targets": {
      "type": "TargetSpec",
      "sensitive": false,
      "description": "List of targets to retrieve the facts for."
    }
  },
  "module_dir": "/Users/bolt/.puppetlabs/bolt/modules/facts"
}
```

## `project init`

This command does not provide JSON output.

## `project migrate`

This command does not provide JSON output.

## `script run`

This command outputs an object. It uses the following keys:

- `elapsed_time` (number):
  The time, in seconds, that it took for the script to run.

- `items` (array of objects):
  A list of objects describing the result of running the script on each target.

  - `action` (string):
    The type of action that was executed. This value is always `script`.

  - `object` (string):
    The path to the script.

  - `status` (string):
    Whether the script completed successfully. This value is `success` if the
    script runs successfully and `failure` otherwise.

  - `target` (string):
    The name of the target that the script ran on.

  - `value` (object):
    The value returned by the script.

    - `exit_code` (number):
      The exit code returned by the script.

    - `merged_output` (string):
      The merged output from `stderr` and `stdout`. Output is merged in the order
      that Bolt receives it, which may be different than the order it was output
      on the target.

    - `stderr` (string):
      Output sent to `stderr`.
      
    - `stdout` (string):
      Output sent to `stdout`.

- `target_count` (number):
  The number of targets that the script ran on.

For example:

```json
{
  "items": [
    {
      "target": "localhost",
      "action": "script",
      "object": "/Users/bolt/.puppetlabs/bolt/files/example.sh",
      "status": "success",
      "value": {
        "stdout": "Hello\n",
        "stderr": "Goodbye\n",
        "merged_output": "Hello\nGoodbye\n",
        "exit_code": 0
      }
    }
  ],
  "target_count": 1,
  "elapsed_time": 1
}
```

## `secret createkeys`

This command does not provide JSON output.

## `secret decrypt`

This command does not provide JSON output.

## `secret encrypt`

This command does not provide JSON output.

## `task run`

This command outputs an object. It uses the following keys:

- `elapsed_time` (number):
  The time, in seconds, that it took for the task to run.

- `items` (array of objects):
  A list of objects describing the result of running the task on each 
  target.

  - `action` (string):
    The type of action that was executed. This value is always `task`.

  - `object` (string):
    The name of the task that was run.

  - `status` (string):
    Whether the task completed successfully. This value is `success` if the
    task completed successfully and `failure` otherwise.

  - `target` (string):
    The name of the target the task ran on.

  - `value` (object):
    The value returned by the task.

- `target_count` (number):
  The number of targets the task ran on.

For example:

```json
{
  "items":[
    {
      "target": "localhost",
      "action": "task",
      "object": "example",
      "status":"success",
      "value":{
        "phrase": "Hello world!"
      }
    }
  ],
  "target_count": 1,
  "elapsed_time": 1
}
```

## `task show`

This command outputs an object. It uses the following keys:

- `modulepath` (array of strings):
  The project's modulepath.

- `tasks` (array of arrays):
  A list of task names and descriptions. Each item in the array is an array,
  where the first item is the task's name and the second item is the task's
  description.

For example:

```json
{
  "modulepath": [
    "/Users/bolt/.puppetlabs/bolt/modules",
    "/Users/bolt/.puppetlabs/bolt/.modules"
  ],
  "tasks": [
    [
      "package",
      "Manage and inspect the state of packages"
    ],
    [
      "service",
      "Manage and inspect the state of services"
    ]
  ]
}
```

## `task show <task>`

This command outputs an object. It uses the following keys:

- `files` (array):
  A list of files to be provided when running the task, addressed by module.
  Each item in the array is an object that includes the `name` of the file and
  the `path` to the file.

- `metadata` (object):
  The [task's metadata](writing_tasks.md#task-metadata-fields).

- `module_dir` (string):
  The path to the task's module.

- `name` (string):
  The task's name.

For example:

```json
{
  "files": [
    {
      "name": "init.sh",
      "path": "/Users/bolt/.puppetlabs/bolt/modules/example/tasks/init.sh"
    }
  ],
  "metadata":{
    "description": "Print a phrase.",
    "parameters": {
      "phrase": {
        "type": "String"
      }
    },
  },
  "module_dir": "/Users/bolt/.puppetlabs/bolt/modules/example",
  "name": "example"
}
```
