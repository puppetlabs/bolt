# Bolt API Servers

## Overview
Bolt has 2 API servers which provide services to run bolt tasks and plans over SSH and WinRM. Services are exposed via APIs as described in this document. Both servers work as a standalone service - the API server for tasks is available in PE Johnson and greater as `pe-bolt-server`, while the server for plans is still in the works as the `plan-executor`. The tasks server is referred to as 'bolt server', while the plan server is referred to as 'plan executor'

## Configuration
Bolt server can be configured by defining content in HOCON format at one of the following expected configuration file path locations.

**Bolt Server Config**: `/etc/puppetlabs/bolt-server/conf.d/bolt-server.conf`

**Plan Executor Config**: `/etc/puppetlabs/plan-executor/conf.d/plan-executor.conf`

**Shared Options**

Most options are shared by the bolt server and plan executor applications
- `host`: String, *optional* - Hostname for server (default "127.0.0.1").
- `port`: Integer, *optional* - The port the bolt server will run on (default 62658).
- `ssl-cert`: String, *required* - Path to the cert file.
- `ssl-key`: String, *required* - Path to the key file.
- `ssl-ca-cert`: String, *required* - Path to the ca cert file.
- `ssl-cipher-suites`: Array, *optional* - TLS cipher suites in order of preference ([default](#default-ssl-cipher-suites)).
- `loglevel`: String, *optional* - Bolt log level, acceptable values are `debug`, `info`, `notice`, `warn`, `error` (default `notice`).
- `logfile`: String, *optional* - Path to log file.
- `whitelist`: Array, *optional* - A list of hosts which can connect to pe-bolt-server.

**Bolt Server Only Options**
- `concurrency`: Integer, *optional* - The maximum number of server threads (default `100`).

**Plan Executor Only Options**
- `modulepath`: String, *required* - The path to modules to read plans from
- `orchestrator-url`: String, *required* - The hostname of the orchestrator service
- `workers`: Integer, *optional* - The number of worker processes to create (default `1`).

**Environment Variable Options**
The following configuration options can be set with environment variables. 
- `BOLT_SSL_CERT`
- `BOLT_SSL_KEY`
- `BOLT_SSL_CA_CERT`
- `BOLT_LOGLEVEL`
- `BOLT_CONCURRENCY`
- `BOLT_FILE_SERVER_CONN_TIMEOUT`
- `BOLT_FILE_SERVER_URI`

**Note**: Configuration options set with environment variables will override those defined in `bolt-server.conf`

### Default SSL Cipher Suites
Based on https://wiki.mozilla.org/Security/Server_Side_TLS#Modern_compatibility
```
ECDHE-ECDSA-AES256-GCM-SHA384
ECDHE-RSA-AES256-GCM-SHA384
ECDHE-ECDSA-CHACHA20-POLY1305
ECDHE-RSA-CHACHA20-POLY1305
ECDHE-ECDSA-AES128-GCM-SHA256
ECDHE-RSA-AES128-GCM-SHA256
ECDHE-ECDSA-AES256-SHA384
ECDHE-RSA-AES256-SHA384
ECDHE-ECDSA-AES128-SHA256
ECDHE-RSA-AES128-SHA256
```

**Example**
```
bolt-server: {
    port: 62658
    ssl-cert: /etc/puppetlabs/bolt-server/ssl/cert.pem
    ssl-key: /etc/puppetlabs/bolt-server/ssl/private_key.pem
    ssl-ca-cert: /etc/puppetlabs/bolt-server/ssl/ca.pem
}
```

## Bolt Server API Endpoints
Each API endpoint accepts a request as described below. The request body must be a JSON object.

### POST /ssh/run_task
- `target`: [SSH Target Object](#ssh-target-object), *required* - Target information to run task on.
- `task`: [Task Object](#task-object), *required* - Task to run on target.
- `parameters`: Object, *optional* - JSON formatted parameters to be provided to task.

For example, the following runs the 'echo' task on linux_target.net:
```
{
  "target": {
    "hostname": "linux_target.net",
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

### POST /winrm/run_task
- `target`: [WinRM Target Object](#winrm-target-object), *required* - Target information to run task on.
- `task`: [Task Object](#task-object), *required* - Task to run on target.
- `parameters`: Object, *optional* - JSON formatted parameters to be provided to task.

For example, the following runs 'sample::complex_params' task on localhost:
```
{
  "target": {
    "hostname": "windows_target.net",
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
### POST /ssh/run_command
- `target`: [SSH Target Object](#ssh-target-object), *required* - Target information to run task on.
- `command`: String, *required* - Command to run on target.

For example, the following runs "echo 'hi'" on linux_target.net:
```
{
  "target": {
    "hostname": "linux_target.net",
    "user": "marauder",
    "password": "I solemnly swear that I am up to no good",
    "host-key-check": false,
    "run-as": "george_weasley"
  },
  "command": "echo 'hi'"
}
```

### POST /winrm/run_command
- `target`: [WinRM Target Object](#winrm-target-object), *required* - Target information to run task on.
- `command`: String, *required* - Command to run on target.

For example, the following runs "echo 'hi'" on localhost:
```
{
  "target": {
    "hostname": "windows_target.net",
    "user": "Administrator",
    "password": "Secret",
    "ssl": false,
    "ssl-verify": false
  },
  "command": "echo 'hi'"
}
```

### POST /ssh/upload_file
- `target`: [SSH Target Object](#ssh-target-object), *required* - Target information to run task on.
- `files`: Object, *required* - Which file(s) to upload, and where.
    - `relative_path`: String, *required* - The destination for the file.
    - `uri`: Object, *required* - The location of where to find the file.
        - `path`: String, *required* - The endpoint to retrieve the file.
        - `params`: Object, *required* - The parameters to supply the endpoint.
    - `sha256`: String, *required* - The SHA256 value for the file.
    - `kind`: String, *required* - Whether the file is a `file` or `directory`.
- `job_id`: Integer, *required* - An identifier for the job. If this matches an existing ID, cached files may be returned.
- `destination`: String, *required* - Where to put the files on the target machine.

For example, the following uploads file 'abc' on linux_target.net:
```
{
  "target": {
    "hostname": "linux_target.net",
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

### POST /winrm/upload_file
- `target`: [WinRM Target Object](#winrm-target-object), *required* - Target information to run task on.
- `files`: Object, *required* - Which file(s) to upload, and where.
    - `relative_path`: String, *required* - The destination for the file.
    - `uri`: Object, *required* - The location of where to find the file.
        - `path`: String, *required* - The endpoint to retrieve the file.
        - `params`: Object, *required* - The parameters to supply the endpoint.
    - `sha256`: String, *required* - The SHA256 value for the file.
    - `kind`: String, *required* - Whether the file is a `file` or `directory`.
- `job_id`: Integer, *required* - An identifier for the job. If this matches an existing ID, cached files may be returned.
- `destination`: String, *required* - Where to put the files on the target machine.

For example, the following uploads file 'abc' on windows_target.net:
```
{
  "target": {
    "hostname": "windows_target.net",
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

### POST /ssh/run_script
- `target`: [SSH Target Object](#ssh-target-object), *required* - Target information to run script on.
- `script`: Object, *required* - The script being executed.
    - `filename`: String, *required* - The destination for the script on the target.
    - `uri`: Object, *required* - The location of where to find the script.
        - `path`: String, *required* - The endpoint to retrieve the script.
        - `params`: Object, *required* - The parameters to supply the endpoint.
    - `sha256`: String, *required* - The SHA256 value for the script.
- `arguments`: String, *optional* - Which arguments to pass to the script.

For example, the following runs script 'file.sh' on linux_target.net:
```
{
  "target": {
    "hostname": "linux_target.net",
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
  "arguments": "--test",
}
```

### POST /winrm/run_script
- `target`: [WinRM Target Object](#winrm-target-object), *required* - Target information to run script on.
- `script`: Object, *required* - The script being executed.
    - `filename`: String, *required* - The destination for the script on the target.
    - `uri`: Object, *required* - The location of where to find the script.
        - `path`: String, *required* - The endpoint to retrieve the script.
        - `params`: Object, *required* - The parameters to supply the endpoint.
    - `sha256`: String, *required* - The SHA256 value for the script.
- `arguments`: String, *optional* - Which arguments to pass to the script.

For example, the following runs script 'file.sh' on windows_target.net:
```
{
  "target": {
    "hostname": "windows_target.net",
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
  "arguments": "-Test",
}
```

### POST /ssh/check_node_connections
- `targets`: An array of [SSH Target Objects](#ssh-target-object), *required* - A set of targets to check once for connectivity over SSH.

Example request for a single connectivity check on two nodes over SSH:
```
{
  "targets": [
      {
        "hostname": "first.ssh_node.net",
        "user": "marauder",
        "password": "I solemnly swear that I am up to no good",
        "host-key-check": false,
        "run-as": "george_weasley"
      }, {
        "hostname": "second.ssh_node.net",
        "user": "marauder",
        "password": "I solemnly swear that I am up to no good",
        "host-key-check": false,
        "run-as": "fred_weasley"
      }
  ]
}
```

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

### POST /winrm/check_node_connections
- `targets`: An array of [WinRM Target Objects](#winrm-target-object), *required* - A set of targets to check once for connectivity over WinRM.

This endpoint behaves identically to the /ssh/check_node_connections endpoint, but acts over WinRM instead.

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

### Response
If the task runs, the response will have status 200.
The response will be a standard bolt Result JSON object.

## Plan Executor API Endpoints
Each API endpoint accepts a request as described below. The request body must be a JSON object.

### POST /plan/run
- `plan_name`: String, *required* - The plan to run
- `environment`: String, *optional* - The environment the plan runs in (default: `production`)
- `job_id`: String, *required* - The ID of the plan_job this plan runs as, from the Orchestrator database.
- `description`: String, *optional* - A description of the plan job being run
- `params`: Hash, *required* - Key-value pairs of parameters to pass to the plan.

For example, the following runs the `canary` plan:
```
{
  "plan_name" : "canary",
  "environment": "production",
  "job_id": "123842",
  "description" : "Start the canary plan on node1 and node2",
  "params" : {
  "nodes" : ["node1.example.com", "node2.example.com"],
  "command" : "whoami",
  "canary" : 1
  }
}
```
#### Response

If successful, this will return
```
{"status": "running"}
```

## Running Bolt Server in a container
*Recommended*

From your checkout of bolt, start the spec docker-compose to run
puppet-server and some targets then run the top level compose to start
bolt-server connected to that network.

```
docker-compose -f spec/docker-compose.yml up -d --build
docker-compose up --build
```

Setup your environment for running commands with
```
export BOLT_CACERT=spec/fixtures/ssl/ca.pem
export BOLT_CERT=spec/fixtures/ssl/cert.pem
export BOLT_KEY=spec/fixtures/ssl/key.pem
export BOLT_ROOT=https://localhost:62658
```

You can now make a curl request to bolt which should have an empty response
```
curl -v --cacert $BOLT_CACERT --cert $BOLT_CERT --key $BOLT_KEY $BOLT_ROOT
```

## Running from source

From your checkout of bolt, run

```
BOLT_SERVER_CONF=config/local.conf bundle exec puma -C puppet_config.rb
```

Setup your environment for running commands with
```
export BOLT_CACERT=spec/fixtures/ssl/ca.pem
export BOLT_CERT=spec/fixtures/ssl/cert.pem
export BOLT_KEY=spec/fixtures/ssl/key.pem
export BOLT_ROOT=https://localhost:62658
```

You can now make a curl request to bolt which should have an empty response
```
curl -v --cacert $BOLT_CACERT --cert $BOLT_CERT --key $BOLT_KEY $BOLT_ROOT
```

## Making requests

### With the ruby client

There is a simple ruby client that can be used to make requests to a local
bolt server during development at `scripts/server_client.rb`. This server
expects to use the puppet-server container and target nodes from bolts spec
environment so follow instructions in the [running in a
container](#running-in-a-container) section first!

```
bundle exec scripts/server_client.rb sample::echo <TARGET> '{"message": "hey"}'
```

Where `<TARGET>` is either:
* A vmpooler VM. To use this, replace `<TARGET>` above with the hostname.
* One of the containers brought up by the `docker-compose` in the `spec` directory. To use these, you'll want to:

    * get the IP that the **bolt-server container** believes it is hosted on (for example the IP of the developer laptop hosting the bolt-server container):
      ```
      bolt command run "/sbin/ip route" -n docker://bolt_boltserver_1 | awk '/default/ { print $3 }'
      # Should return an IP such as 172.20.0.1
      ```
    * Append the port of one of the 3 containers to that IP: `20022` (for an ubuntu node with no agent), `20023` (for a puppet 5 agent), or `20024` (for a puppet 6 agent). It's also helpful to include the protocol (`ssh`), user (`bolt`), and password (`bolt`) in the URI.

So your request will be something like:
```
bundle exec scripts/server_client.rb sample::echo ssh://bolt:bolt@172.20.0.1:20022 '{"message": "hey"}'
```

**Note**: All tasks in the `bolt/spec/fixtures/modules` directory will be available from the puppetserver container to run.

### With cURL

The following is an example request body. There are other request examples in the `developer-docs/examples` directory. Note that all tasks in the `bolt/spec/fixtures/modules` are available from the puppetserver container, so a JSON request can be constructed using those tasks and the JSON structure below.

```
{"task":{
  "metadata":{},
  "name":"sample::echo",
  "files":[{
    "filename":"echo.sh",
    "sha256":"c5abefbdecee006bd65ef6f625e73f0ebdd1ef3f1b8802f22a1b9644a516ce40",
    "size_bytes":64,
    "uri":{
      "path":"/puppet/v3/file_content/tasks/sample/echo.sh",
      "params":{
        "environment":"production"}}}]},
"target":{
  "hostname":"172.20.0.1",
  "user":"bolt",
  "password":"bolt",
  "port": 20022,
  "host-key-check":false},
"parameters":{
  "message":"hey"}}
```
**Verify that the target information** is correct, and change it if you want to use a different target. You can find other example requests in the `examples` directory.

You should then be able to post it with:
```
curl -X POST -H "Content-Type: application/json" -d @developer-docs/examples/ssh-echo.json --cacert $BOLT_CACERT --cert $BOLT_CERT --key $BOLT_KEY $BOLT_ROOT/ssh/run_task
```
expected output
```
{"node":"172.18.0.1",
"status":"success",
"result":{"_output":"ac80223bd3b4 got passed the message: hey\n"}}
```
