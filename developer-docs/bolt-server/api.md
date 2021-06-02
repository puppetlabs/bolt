# Bolt Server API

## Overview
Bolt has an API service (`pe-bolt-server`) that provides the ability to run tasks and plans over SSH/WinRM, retrieve task and plan metadata, and resolve project inventory.

## POST /ssh/run_task
- `target`: [SSH Target Object](#ssh-target-object), *required* - Target information to run task on.
- `task`: [Task Object](#task-object), *required* - Task to run on target.
- `parameters`: Object, *optional* - JSON formatted parameters to be provided to task.

For example, the following runs the 'echo' task on linux-target.example.com:
```
{
  "target": {
    "hostname": "linux-target.example.com",
    "user": "marauder",
    "password": "I solemnly swear that I am up to no good",
    "host-key-check": false,
    "run-as": "george_weasley"
  },
  "task": {
    "metadata":{},
    "name":"sample::echo",
    "files":[{
      "filename":"echo.sh",
      "sha256":"c5abefbdecee006bd65ef6f625e73f0ebdd1ef3f1b8802f22a1b9644a516ce40",
      "size_bytes":64,
      "uri":{
        "path":"/puppet/v3/file_content/tasks/sample/echo.sh",
        "params":{
          "environment":"production"}
      }
    }]
  },
  "parameters": {
    "message": "Hello world"
  }
}
```

### Response
If the task runs, the response will have status 200.
The response will be a standard bolt Result JSON object.


## POST /winrm/run_task
- `target`: [WinRM Target Object](#winrm-target-object), *required* - Target information to run task on.
- `task`: [Task Object](#task-object), *required* - Task to run on target.
- `parameters`: Object, *optional* - JSON formatted parameters to be provided to task.

For example, the following runs 'sample::complex\_params' task on windows-target.example.com:
```
{
  "target": {
    "hostname": "windows-target.example.com",
    "user": "Administrator",
    "password": "Secret",
    "ssl": false,
    "ssl-verify": false
  },
  "task": {
    "metadata":{},
    "name":"sample::complex_params",
    "files":[{
      "filename":"complex_params.ps1",
      "sha256":"e070a96387e0d339bf12fe3e00da74c6bfb3b7ebc54bd506d6bc2831030ccf5d",
      "size_bytes":2016,
      "uri":{
        "path":"/puppet/v3/file_content/tasks/sample/complex_params.ps1",
        "params":{
          "environment":"production"}
      }
    }]
  },
  "parameters": {
    "message": "Hello world"
  }
}
```

### Response
If the task runs, the response will have status 200.
The response will be a standard bolt Result JSON object.


## POST /ssh/run_command
- `target`: [SSH Target Object](#ssh-target-object), *required* - Target information to run task on.
- `command`: String, *required* - Command to run on target.

For example, the following runs "echo 'hi'" on linux-target.example.com:
```
{
  "target": {
    "hostname": "linux-target.example.com",
    "user": "marauder",
    "password": "I solemnly swear that I am up to no good",
    "host-key-check": false,
    "run-as": "george_weasley"
  },
  "command": "echo 'hi'"
}
```

## POST /winrm/run_command
- `target`: [WinRM Target Object](#winrm-target-object), *required* - Target information to run task on.
- `command`: String, *required* - Command to run on target.

For example, the following runs "echo 'hi'" on windows-target.example.com:
```
{
  "target": {
    "hostname": "windows-target.example.com",
    "user": "Administrator",
    "password": "Secret",
    "ssl": false,
    "ssl-verify": false
  },
  "command": "echo 'hi'"
}
```

## POST /ssh/upload_file
- `target`: [SSH Target Object](#ssh-target-object), *required* - Target information to run task on.
- `files`: Object, *required* - Which file(s) to upload, and where.
    - `relative_path`: String, *required* - The destination for the file.
    - `uri`: Object, *required* - The location of where to find the file.
        - `path`: String, *required* - The endpoint to retrieve the file.
        - `params`: Object, *required* - The parameters to supply the endpoint.
    - `sha256`: String, *required* - The SHA256 value for the file.
    - `kind`: String, *required* - Whether the file is a `file` or `directory`.
- `job_id`: Integer, *required* - An identifier for the job. If this matches an existing ID, cached files might be returned.
- `destination`: String, *required* - Where to put the files on the target machine.

For example, the following uploads file 'abc' on linux-target.example.com:
```
{
  "target": {
    "hostname": "linux-target.example.com",
    "user": "marauder",
    "password": "I solemnly swear that I am up to no good",
    "host-key-check": false,
    "run-as": "george_weasley"
  },
  "destination": "/home/bolt/root",
  "job_id": 1,
  "files" : [{
    "relative_path": "file.sh"
    "uri": {
      "path": "/puppet/v3/file_content/modules/some_module/file.sh",
      "params": {}
    },
    "sha256": "SHA256VALUE",
    "kind": "file"
  }]
}
```

## POST /winrm/upload_file
- `target`: [WinRM Target Object](#winrm-target-object), *required* - Target information to run task on.
- `files`: Object, *required* - Which file(s) to upload, and where.
    - `relative_path`: String, *required* - The destination for the file.
    - `uri`: Object, *required* - The location of where to find the file.
        - `path`: String, *required* - The endpoint to retrieve the file.
        - `params`: Object, *required* - The parameters to supply the endpoint.
    - `sha256`: String, *required* - The SHA256 value for the file.
    - `kind`: String, *required* - Whether the file is a `file` or `directory`.
- `job_id`: Integer, *required* - An identifier for the job. If this matches an existing ID, cached files might be returned.
- `destination`: String, *required* - Where to put the files on the target machine.

For example, the following uploads file 'abc' on windows-target.example.com:
```
{
  "target": {
    "hostname": "windows-target.example.com",
    "user": "Administrator",
    "password": "Secret",
    "ssl": false,
    "ssl-verify": false
  },
  "destination": "C:\\Users\\bolt\\root",
  "job_id": 1,
  "files" : [{
    "relative_path": "file.exe"
    "uri": {
      "path": "/puppet/v3/file_content/modules/some_module/file.exe",
      "params": {}
    },
    "sha256": "SHA256VALUE",
    "kind": "file"
  }]
}
```

## POST /ssh/run_script
- `target`: [SSH Target Object](#ssh-target-object), *required* - Target information to run script on.
- `script`: Object, *required* - The script being executed.
    - `filename`: String, *required* - The destination for the script on the target.
    - `uri`: Object, *required* - The location of where to find the script.
        - `path`: String, *required* - The endpoint to retrieve the script.
        - `params`: Object, *required* - The parameters to supply the endpoint.
    - `sha256`: String, *required* - The SHA256 value for the script.
- `arguments`: Array, *optional* - Which arguments to pass to the script.

For example, the following runs script 'file.sh' on linux-target.example.com:
```
{
  "target": {
    "hostname": "linux-target.example.com",
    "user": "marauder",
    "password": "I solemnly swear that I am up to no good",
    "host-key-check": false,
    "run-as": "george_weasley"
  },
  "script" : {
    "filename": "file.sh",
    "uri": {
      "path": "/puppet/v3/file_content/modules/some_module/file.sh",
      "params": {}
    },
    "sha256": "SHA256VALUE"
  },
  "arguments": ["--test"],
}
```

## POST /winrm/run_script
- `target`: [WinRM Target Object](#winrm-target-object), *required* - Target information to run script on.
- `script`: Object, *required* - The script being executed.
    - `filename`: String, *required* - The destination for the script on the target.
    - `uri`: Object, *required* - The location of where to find the script.
        - `path`: String, *required* - The endpoint to retrieve the script.
        - `params`: Object, *required* - The parameters to supply the endpoint.
    - `sha256`: String, *required* - The SHA256 value for the script.
- `arguments`: Array, *optional* - Which arguments to pass to the script.

For example, the following runs script 'file.sh' on windows-target.example.com:
```
{
  "target": {
    "hostname": "windows-target.example.com",
    "user": "Administrator",
    "password": "Secret",
    "ssl": false,
    "ssl-verify": false
  },
  "script" : {
    "filename": "file.ps1",
    "uri": {
      "path": "/puppet/v3/file_content/modules/some_module/file.ps1",
      "params": {}
    },
    "sha256": "SHA256VALUE"
  },
  "arguments": ["-Test"],
}
```

## POST /ssh/check_node_connections
- `targets`: An array of [SSH Target Objects](#ssh-target-object), *required* - A set of targets to check once for connectivity over SSH.

Example request for a single connectivity check on two nodes over SSH:
```
{
  "targets": [
      {
        "hostname": "first-sshnode.example.com",
        "user": "marauder",
        "password": "I solemnly swear that I am up to no good",
        "host-key-check": false,
        "run-as": "george_weasley"
      }, {
        "hostname": "second-sshnode.example.com",
        "user": "marauder",
        "password": "I solemnly swear that I am up to no good",
        "host-key-check": false,
        "run-as": "fred_weasley"
      }
  ]
}
```
### Response

This returns a JSON object of the shape:
```
{
    "status": "success",
    "result": [
        {
            "status": "success"
            "target": "first.ssh_node.net"
            ...
        }, {
            "status": "success"
            "target": "second.ssh_node.net"
            ...
        }
    ]
}
```

- This endpoint returns 200 when the checks were successfully conducted, even if some or all of the individual checks failed.
- If at least one check failed, the parent result `status` will be set to `failure`.

## POST /winrm/check_node_connections
- `targets`: An array of [WinRM Target Objects](#winrm-target-object), *required* - A set of targets to check once for connectivity over WinRM.

This endpoint behaves identically to the /ssh/check_node_connections endpoint, but acts over WinRM instead.

## POST /project_inventory_targets

This endpoint parses a project inventory and returns a list of target hashes. Note that the only accepetable inventory file location is the default `inventory.yaml` at the root of the project.

### Query parameters

- `versioned_project`: String, *required* - Reference to the bolt project (in the form [PROJECT NAME]\_[REF])

### POST body

- `connect_data`: Hash, *required* - Data for the Connect plugin to look up. Keys are the lookup in the inventory file which points to a hash with a required "value" key that points to the value to look up.

### Request

```
{
  "connect_data": {
    "ssh_password": {
      "value": "foo"
    }
  }
}
```

### Response

Returns a list of targets parsed from project inventory
```
[
  {
    "name": "one",
    "transport": "ssh",
    "cleanup": true,
    "connect-timeout": 10,
    "disconnect-timeout": 5,
    "load-config": true,
    "login-shell": "bash",
    "tty": false,
    "uri": "one",
    "protocol": "ssh",
    "user": null,
    "password": null,
    "host": "one",
    "port": null
  },
  {
    "name": "two",
    "transport": "ssh",
    "cleanup": true,
    "connect-timeout": 10,
    "disconnect-timeout": 5,
    "load-config": true,
    "login-shell": "bash",
    "tty": false,
    "uri": "two",
    "protocol": "ssh",
    "user": null,
    "password": null,
    "host": "two",
    "port": null
  }
]

## GET /project_facts_plugin_tarball

This endpoint returns the base64 encoded tar archive of plugin code that is needed to calculate custom facts.

### Query parameters

- `versioned_project`: String, *required* - Reference to the bolt project (in the form [PROJECT NAME]\_[REF])

### Response

```
"H4sIAI7ot2AAA+2UywqDMBBFXfsVAfcm0RihPxOiRhtIY8gDSr++UbCrQtGF\nLSVnN7O5A5czRoVJ6pH33rHbPAQl4DqUAxR3L6zmii2L0l2zo6AIJeTtfqVC\nGSaoaVpa4xZnCDe4ohlAhxN3EJznNp5yRtYPUoCtZrDUnH/7nsS5mNX/TX0l\nO2iCMcLDMejey1k76OabYNtY2m53xkf/G/ryn9Qk+k9bXCf/z6AAo50fQjPn\nrdQTUzJ+A64uwNsg8gIs5YOt/PQdEolE4m94AocSIJ4ADAAA\n"
```

## GET /tasks
- `environment`: String

### Response

This returns a JSON array of this shape:

```
[
  {
    "name": "package"
  },
  {
    "name": "service"
  }
]
```

## GET /tasks/:module/:taskname
- `environment`: String

### Response

This returns a JSON object of this shape:

```
{
  "metadata": {
    "description": "Manage and inspect the state of services",
    "input_method": "stdin",
    "parameters": {
      "action": {
        "description": "The operation (start, stop, restart, enable, disable, status) to perform on the service.",
        "type": "Enum[start, stop, restart, enable, disable, status]"
      },
      "name": {
        "description": "The name of the service to operate on.",
        "type": "String[1]"
      },
      "force": {
        "description": "Force a Windows service to restart even if it has dependent services. This parameter is passed for Windows services only.",
        "type": "Optional[Boolean]"
      },
      "provider": {
        "description": "The provider to use to manage or inspect the service, defaults to the system service manager. Only used when the 'puppet-agent' feature is available on the target so we can leverage Puppet.",
        "type": "Optional[String[1]]"
      }
    },
    "implementations": [
      {
        "name": "init.rb",
        "requirements": [
          "puppet-agent"
        ]
      },
      {
        "name": "windows.ps1",
        "requirements": [
          "powershell"
        ],
        "input_method": "powershell"
      },
      {
        "name": "linux.sh",
        "requirements": [
          "shell"
        ],
        "input_method": "environment",
        "files": [
          "service/files/common.sh"
        ]
      }
    ],
    "extensions": {
      "discovery": {
        "friendlyName": "Manage service",
        "type": [
          "host"
        ]
      }
    }
  },
  "name": "service",
  "files": [
    {
      "filename": "init.rb",
      "sha256": "da9441915636b2a231bca3da898788920490b8a061eb28b086f079da72dd3141",
      "size_bytes": 1285,
      "uri": {
        "path": "/puppet/v3/file_content/tasks/service/init.rb",
        "params": {
          "environment": "production"
        }
      }
    },
    {
      "filename": "windows.ps1",
      "sha256": "a706b8c127b1aa72d7c75d6fbb0833d25abc97db89197f9b3faadf1caf688964",
      "size_bytes": 2636,
      "uri": {
        "path": "/puppet/v3/file_content/tasks/service/windows.ps1",
        "params": {
          "environment": "production"
        }
      }
    },
    {
      "filename": "linux.sh",
      "sha256": "71d6bae0c580529d7c1a84e865bc08606aa5f8d6f627ef5083a2bc6918338cab",
      "size_bytes": 4220,
      "uri": {
        "path": "/puppet/v3/file_content/tasks/service/linux.sh",
        "params": {
          "environment": "production"
        }
      }
    },
    {
      "filename": "service/files/common.sh",
      "sha256": "dbe3a6bdf0382a311b2cc885128b1069b3749c7bb3fef1143348179f0a659c30",
      "size_bytes": 1120,
      "uri": {
        "path": "/puppet/v3/file_content/modules/service/common.sh",
        "params": {
          "environment": "production"
        }
      }
    }
  ]
}
```

## GET /project_tasks
- `versioned_project`: String, *required* - Reference to the bolt project (in the form [PROJECT NAME]\_[REF])

### Response

```
[
  {
    "name": "facts",
    "allowed": true
  },
  {
    "name": "package",
    "allowed": true
  }
]
```

## GET /project_tasks/:module_name/:task_name
- `versioned_project`: String, *required* - Reference to the bolt project (in the form [PROJECT NAME]\_[REF])

### Response

```
{
  "metadata": {
    "description": "Manage and inspect the state of services",
    "input_method": "stdin",
    "parameters": {
      "action": {
        "description": "The operation (start, stop, restart, enable, disable, status) to perform on the service.",
        "type": "Enum[start, stop, restart, enable, disable, status]"
      },
      "name": {
        "description": "The name of the service to operate on.",
        "type": "String[1]"
      },
      "force": {
        "description": "Force a Windows service to restart even if it has dependent services. This parameter is passed for Windows services only.",
        "type": "Optional[Boolean]"
      },
      "provider": {
        "description": "The provider to use to manage or inspect the service, defaults to the system service manager. Only used when the 'puppet-agent' feature is available on the target so we can leverage Puppet.",
        "type": "Optional[String[1]]"
      }
    },
    "implementations": [
      {
        "name": "init.rb",
        "requirements": [
          "puppet-agent"
        ]
      },
      {
        "name": "windows.ps1",
        "requirements": [
          "powershell"
        ],
        "input_method": "powershell"
      },
      {
        "name": "linux.sh",
        "requirements": [
          "shell"
        ],
        "input_method": "environment",
        "files": [
          "service/files/common.sh"
        ]
      }
    ],
    "extensions": {
      "discovery": {
        "friendlyName": "Manage service",
        "type": [
          "host"
        ]
      }
    }
  },
  "name": "service",
  "files": [
    {
      "filename": "init.rb",
      "sha256": "da9441915636b2a231bca3da898788920490b8a061eb28b086f079da72dd3141",
      "size_bytes": 1285,
      "uri": {
        "path": "/puppet/v3/file_content/tasks/service/init.rb",
        "params": {
          "project": "my_project_somesha"
        }
      }
    },
    {
      "filename": "windows.ps1",
      "sha256": "a706b8c127b1aa72d7c75d6fbb0833d25abc97db89197f9b3faadf1caf688964",
      "size_bytes": 2636,
      "uri": {
        "path": "/puppet/v3/file_content/tasks/service/windows.ps1",
        "params": {
          "project": "my_project_somesha"
        }
      }
    },
    {
      "filename": "linux.sh",
      "sha256": "71d6bae0c580529d7c1a84e865bc08606aa5f8d6f627ef5083a2bc6918338cab",
      "size_bytes": 4220,
      "uri": {
        "path": "/puppet/v3/file_content/tasks/service/linux.sh",
        "params": {
          "project": "my_project_somesha"
        }
      }
    },
    {
      "filename": "service/files/common.sh",
      "sha256": "dbe3a6bdf0382a311b2cc885128b1069b3749c7bb3fef1143348179f0a659c30",
      "size_bytes": 1120,
      "uri": {
        "path": "/puppet/v3/file_content/modules/service/common.sh",
        "params": {
          "project": "my_project_somesha"
        }
      }
    }
  ],
  "allowed": true
}
```

## GET /plans
- `environment`: String

### Response

This returns a JSON array of this shape:

```
[
  {
    "name": "facts"
  },
  {
    "name": "facts::info"
  }
]
```

## GET /plans/:module/:planname
- `environment`: String

### Response

This returns a JSON object of this shape:

```
{
  "name": "facts",
  "description": "A plan that retrieves facts and stores in the inventory for the\nspecified targets.\n\nThe $targets parameter is a list of targets to retrieve the facts for.",
  "parameters": {
    "targets": {
      "type": "TargetSpec",
      "sensitive": false
    }
  }
}

```

## GET /project_plans
- `versioned_project`: String, *required* - Reference to the bolt project (in the form [PROJECT NAME]\_[REF])

### Response

```
[
  {
    "name": "facts",
    "allowed": true
  },
  {
    "name": "facts::info",
    "allowed": true
  }
]
```

## GET /project_plans/:module_name/:plan_name
- `versioned_project`: String, *required* - Reference to the bolt project (in the form [PROJECT NAME]\_[REF])

### Response

```
{
  "name": "facts",
  "description": "A plan that retrieves facts and stores in the inventory for the\nspecified targets.\n\nThe $targets parameter is a list of targets to retrieve the facts for.",
  "parameters": {
    "targets": {
      "type": "TargetSpec",
      "sensitive": false
    }
  },
  "allowed": true
}

```

## GET /project_file_metadatas/:module_name/path/to/file
- `versioned_project`: String, *required* - Reference to the bolt project (in the form [PROJECT NAME]\_[REF])

### Response

```
[
  {
    "path": "/opt/puppetlabs/server/data/orchestration-services/projects/my_project_someref/modules/plan_functions/files/test_files",
    "relative_path": ".",
    "links": "follow",
    "owner": 996,
    "group": 994,
    "mode": 420,
    "checksum": {
      "type": "ctime",
      "value": "{ctime}2020-10-13 19:16:27 +0000"
    },
    "type": "directory",
    "destination": null
  },
  {
    "path": "/opt/puppetlabs/server/data/orchestration-services/projects/my_project_someref/modules/plan_functions/files/test_files",
    "relative_path": "test1.txt",
    "links": "follow",
    "owner": 996,
    "group": 994,
    "mode": 420,
    "checksum": {
      "type": "sha256",
      "value": "{sha256}8f2e3615923fecaa8db7fbaef12a38020bc9f6c93f68eb031bcd9776e61153f0"
    },
    "type": "file",
    "destination": null
  },
  {
    "path": "/opt/puppetlabs/server/data/orchestration-services/projects/my_project_someref/modules/plan_functions/files/test_files",
    "relative_path": "subdir",
    "links": "follow",
    "owner": 996,
    "group": 994,
    "mode": 420,
    "checksum": {
      "type": "ctime",
      "value": "{ctime}2020-10-13 19:16:27 +0000"
    },
    "type": "directory",
    "destination": null
  },
  {
    "path": "/opt/puppetlabs/server/data/orchestration-services/projects/my_project_someref/modules/plan_functions/files/test_files",
    "relative_path": "test_link.txt",
    "links": "follow",
    "owner": 996,
    "group": 994,
    "mode": 420,
    "checksum": {
      "type": "sha256",
      "value": "{sha256}8f2e3615923fecaa8db7fbaef12a38020bc9f6c93f68eb031bcd9776e61153f0"
    },
    "type": "file",
    "destination": null
  },
  {
    "path": "/opt/puppetlabs/server/data/orchestration-services/projects/my_project_someref/modules/plan_functions/files/test_files",
    "relative_path": "subdir/test2.txt",
    "links": "follow",
    "owner": 996,
    "group": 994,
    "mode": 420,
    "checksum": {
      "type": "sha256",
      "value": "{sha256}bd3b09cc9f62e80f0b1593a7ed07e68e80d7415f6df13c16f1a541fc074e0acc"
    },
    "type": "file",
    "destination": null
  }
]
```

## Target Schemas

### SSH Target Object
The Target is a JSON object. See the [schema](../lib/bolt_server/schemas/partials/target-ssh.json)

### WinRM Target Object
The Target is a JSON object. See the [schema](../lib/bolt_server/schemas/partials/target-winrm.json)

### Task Object
This is nearly identical to the [task detail JSON
object](https://github.com/puppetlabs/puppetserver/blob/master/documentation/puppet-api/v3/task_detail.json)
from [puppetserver](https://github.com/puppetlabs/puppetserver), with an
additional `file_content` key.

See the [schema](../lib/bolt_server/schemas/task.json). The task is a JSON object which includes the following keys:

#### Name

The name of the task

#### Metadata
The metadata object is optional, and contains metadata about the task being run. It includes the following keys:

- `description`: String, *optional* - The task description from its metadata.
- `parameters`: Object, *optional* - A JSON object whose keys are parameter names, and whose values are JSON objects with 2 keys:
    - `description`: String, *optional* - The parameter description.
    - `type`: String, *optional* - The type the parameter should accept.
    - `sensitive`: Boolean, *optional* - Whether the task runner should treat the parameter value as sensitive
    - `input_method`: String, *optional* - What input method should be used to pass params to task (stdin, environment, powershell)

#### Files
The files array is required, and contains details about the files the task needs as well as how to get them. Array items should be objects with the following keys:
- `uri`: Object, *required* - Information on how to request task files
    - `path`: String, *required* - Relative URI for requesting task content
    - `params`: Object, *required* - Query parameters for locating task data
        - `environment`: String, *required* - Environment task files are in
- `sha256`: String, *required* - Shasum of the file contents
- `filename`: String, *required* - File name including extension
- `size`: Number, *optional* - Size of file in Bytes

## Error responses

Error responses follow the standard `kind`, `msg`, `details` object structure. Some examples:

```
{
  "kind": "bolt/unknown-plan",
  "msg": "Could not find a plan named 'defaults'. For a list of available plans, run 'bolt plan show'.",
  "details": {}
}
```

```
{
  "kind": "bolt-server/request-error",
  "msg": "environment: 'prod' does not exist",
  "details": {}
}
```

```
{
  "kind": "bolt-server/request-error",
  "msg": "'environment' is a required argument",
  "details": {}
}
```

```
{
  "kind": "bolt-server/request-error",
  "msg": "There was an error validating the request body.",
  "details": [
    "The property '#/target' contains additional properties [\"ssl\", \"ssl-verify\"] outside of the schema when none are allowed in schema partial:target-ssh"
  ]
}
```
