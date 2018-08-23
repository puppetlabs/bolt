# Bolt Server 

## Overview
Bolt server provides a service to run bolt tasks over SSH and WinRM. This service is exposed via an API as described in this document. Bolt server works as a standalone service, and is available in PE Johnson and greater as `pe-bolt-server`.

## Configuration
Bolt server can be configured by defining content in HOCON format at one of the following expected configuration file path locations.

**Global Config**: `/etc/puppetlabs/bolt-server/conf.d/bolt-server.conf`

**Local Config**: `~/.puppetlabs/bolt-server.conf`

**Options**
- `port`: Integer, *optional* - The port the bolt server will run on (default 62658)
- `ssl-cert`: String, *required* - Path to the cert file.
- `ssl-key`: String, *required* - Path to the key file.
- `ssl-ca-cert`: String, *required* - Path to the ca cert file.

**Example**
```
bolt-server: {
    port: 62658
    ssl-cert: /etc/puppetlabs/bolt-server/ssl/cert.pem
    ssl-key: /etc/puppetlabs/bolt-server/ssl/private_key.pem
    ssl-ca-cert: /etc/puppetlabs/bolt-server/ssl/ca.pem
} 
```

## API Endpoints
Each API endpoint accepts a request as described below. The request body must be a JSON object.

## POST /ssh/run_task
- `target`: [SSH Target Object](#ssh-target-object), *required* - Target information to run task on.
- `task`: [Task Object](#task-object), *required* - Task to run on target.
- `parameters`: Object, *optional* - JSON formatted parameters to be provided to task.

For example, the following runs the 'echo' task on localhost:
```
{
  "target": {
    "hostname": "localhost",
    "user": "marauder",
    "password": "I solemnly swear that I am up to no good",
    "host-key-check": "false"
  },
  "task": {
    "name": "echo",
    "metadata": {
      "description": "Echo a message",
      "parameters": {
        "message": "Default string"
      }
    },
    "file": {
      "filename": "echo.rb",
      "file_content": "IyEvdXNyL2Jpbi9lbnYgYmFzaAplY2hvICRQVF9tZXNzYWdlCg==\n"
    }
  },
  "parameters": {
    "message": "Hello world"
  }
}
```

## POST /winrm/run_task
- `target`: [WinRM Target Object](#winrm-target-object), *required* - Target information to run task on.
- `task`: [Task Object](#task-object), *required* - Task to run on target.
- `parameters`: Object, *optional* - JSON formatted parameters to be provided to task.

For example, the following runs 'echo' task on localhost:
```
{
  "target": {
    "hostname": "localhost",
    "user": "chamber-of-secrets",
    "password": "parseltongue",
    "host-key-check": "false"
  },
  "task": {
    "name": "echo",
    "metadata": {
      "description": "Echo a message",
      "parameters": {
        "message": "Default string"
      }
    },
    "file": {
      "filename": "echo.rb",
      "file_content": "IyEvdXNyL2Jpbi9lbnYgYmFzaAplY2hvICRQVF9tZXNzYWdlCg==\n"
    }
  },
  "parameters": {
    "message": "Hello world"
  }
}

```

### SSH Target Object
The Target be a JSON object. The following keys are available:
- `hostname`: String, *required* - Target identifier.
- `password`: String, *optional* - Password for SSH transport authentication.
- `port`: Integer, *optional* - Connection port (Default: `22`).
- `user`: String, *optional* - Login user (Default: `root`).
- `connect-timeout`: Integer, *optional* - How long Bolt should wait when establishing connections.
- `run-as-command`: Array, *optional* - Command elevate permissions. Bolt appends the user and command strings to the configured `run-as` command before running it on the target. This command must not require an interactive password prompt, and the `sudo-password` option is ignored when `run-as-command` is specified.
- `run-as`: String, *optional* - A different user to run commands as after login.
- `tmpdir`: String, *optional* - The directory to upload and execute temporary files on the target.
- `host-key-check`: Bool, *optional* - Whether to perform host key validation when connecting over SSH (Default: `true`).
- `sudo-password`: String, *optional* - Password to use when changing users via `run-as`

### WinRM Target Object
The Target be a JSON object. The following keys are available:
- `hostname`: String, *required* - Target identifier.
- `password`: String, *optional* - Password for WinRM transport authentication.
- `port`: Integer, *optional* - Connection port (Default: `5986`, or `5985` if `ssl: false`.)
- `user`: String, *optional* - Login user (Default: `root`).
- `connect-timeout`: Integer, *optional* - How long Bolt should wait when establishing connections.
- `tmpdir`: String, *optional* - The directory to upload and execute temporary files on the target.
- `ssl`: Boolean, *optional* - When true, Bolt will use https connections for WinRM (Default: `true`).
- `ssl-verify`: Boolean, *optional* - When true, verifies the targets certificate matches the cacert (Default: `true`)
- `tmpdir`: String, *optional* - The directory to upload and execute temporary files on the target.
- `cacert`: String, *optional* - The path to the CA certificate.
- `extensions`: List, *optional* - List of file extensions that are accepted for scripts or tasks. Scripts with these file extensions rely on the target node's file type association to run. For example, if Python is installed on the system, a .py script should run with python.exe. The extensions .ps1, .rb, and .pp are always allowed and run via hard-coded executables

### Task Object
This is nearly identical to the [task detail JSON
object](https://github.com/puppetlabs/puppetserver/blob/master/documentation/puppet-api/v3/task_detail.json)
from [puppetserver](https://github.com/puppetlabs/puppetserver), with an
additional `file_content` key.

The task is a JSON object which includes the following keys:

#### Name

The name of the task

#### Metadata
The metadata object is optional, and contains metadata about the task being run. It includes the following keys:

- `description`: String, *optional* - The task description from it's metadata
- `parameters`: Object, *optional* - A JSON object whose keys are parameter names, and whose values are JSON objects with 2 keys:
    - `description`: String, *optional* - The parameter description
    - `type`: String, *optional* - The type the parameter should accept

#### File
**NOTE**: We plan to eventually get this information directly from puppetserver

The task file and it's metadata. This is a JSON object that includes the following keys:
- `filename`: String, *required* - The name of the file the task is in. Note: Will reject any string that contains `/` if using SSH transport, and any string that contains `\` if using WinRM.
- `file_content`: String, *required* - Task's base64 encoded file content.

For example:
```
{
  "name": "package",
  "metadata": {
    "description": "Install a package",
    "parameters": {
      "name": {
        "description": "The package to install",
        "type": "String[1]"
      }
    }
  },
  "file": {
    "filename": "package.rb",
    "file_content": "IyEvdXNyL2Jpbi9lbnYgYmFzaAplY2hvICRQVF9tZXNzYWdlCg==\n"
  }
}
```

## Response 
If the task runs the response will have status 200.
The response will be a standard bolt Result JSON object.

## Setup for manual testing changes

The following example walks through the setup to get the bolt-server running on an Ubuntu 16.04 vmpooler node. 

1. Download and install puppet6 and puppetserver (for certs). The latest release can be found at http://nightlies.puppet.com/
```
curl -O http://nightlies.puppet.com/apt/puppet6-nightly-release-xenial.deb
dpkg -i ./puppet6-nightly-release-xenial.deb 
apt-get update
apt-get install puppetserver
export PATH=$PATH:/opt/puppetlabs/bin
puppet resource service puppetserver ensure=running
```
2. Get certs (Error messages OK here, as long as certs are generated)
```
puppet agent -t
puppet cert list -a
puppet cert sign [host reported from command above]
```
Check that the following certs have been generated
```
/etc/puppetlabs/puppet/ssl/certs/$HOSTNAME.pem
/etc/puppetlabs/puppet/ssl/private_keys/$HOSTNAME.pem
```
3. Download and install bolt-server. The latest release can be found at http://builds.delivery.puppetlabs.net/pe-bolt-server
```
curl -O http://builds.delivery.puppetlabs.net/pe-bolt-server/0.21.7/artifacts/deb/xenial/pe-bolt-server_0.21.7-1xenial_amd64.deb
dpkg -i pe-bolt-server_0.21.7-1xenial_amd64.deb
```
4. Copy over certs to bolt-server directory

- `cp /etc/puppetlabs/puppet/ssl/certs/$HOSTNAME.pem /etc/puppetlabs/bolt-server/ssl/$HOSTNAME.cert.pem`
- `cp /etc/puppetlabs/puppet/ssl/private_keys/$HOSTNAME.pem /etc/puppetlabs/bolt-server/ssl/$HOSTNAME.key.pem`
- `cp /etc/puppetlabs/puppet/ssl/certs/ca.pem /etc/puppetlabs/bolt-server/ssl/ca.pem`
5. Write config file
Save following as `/etc/puppetlabs/bolt-server/conf.d/bolt-server.conf`
```
bolt-server: {
  ssl-cert: "/etc/puppetlabs/bolt-server/ssl/$HOSTNAME.cert.pem"
  ssl-key: "/etc/puppetlabs/bolt-server/ssl/$HOSTNAME.key.pem"
  ssl-ca-cert: "/etc/puppetlabs/bolt-server/ssl/ca.pem"
}
```
6. Grant permissions to bolt-server

`chown -R pe-bolt-server:pe-bolt-server /etc/puppetlabs/bolt-server/*`

7. Start bolt-server
`service pe-bolt-server start`
8. Build a request
Save the following JSON to `~/request.json`
```
{
  "target": {
    "hostname": "juvct8xnyr2ihvm.delivery.puppetlabs.net",
    "user": "root",
    "password": "Secret",
    "host-key-check": "false"
  },
  "task": {
    "name": "echo",
    "metadata": {
      "description": "Echo a message",
      "parameters": {
        "message": "Default string"
      }
    },
    "file": {
      "filename": "echo.rb",
      "file_content": "IyEvdXNyL2Jpbi9lbnYgYmFzaAplY2hvICRQVF9tZXNzYWdlCg==\n"
    }
  },
  "parameters": {
    "message": "Hello world"
  }
}
```
9. Make request
```
curl -X POST -H "Content-Type: application/json" -d @request.json -E /etc/puppetlabs/bolt-server/ssl/$HOSTNAME.cert.pem --key /etc/puppetlabs/bolt-server/ssl/$HOSTNAME.key.pem -k https://0.0.0.0:62658/ssh/run_task

```
10. Expected Output
```
{ "node":"juvct8xnyr2ihvm.delivery.puppetlabs.net",
  "status":"success",
  "result": { "_output":"Hello world\n" }
}
```
