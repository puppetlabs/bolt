# Bolt Server

## Overview
Bolt server provides a service to run bolt tasks over SSH and WinRM. This service is exposed via an API as described in this document. Bolt server works as a standalone service, and is available in PE Johnson and greater as `pe-bolt-server`.

## Configuration
Bolt server can be configured by defining content in HOCON format at one of the following expected configuration file path locations.

**Global Config**: `/etc/puppetlabs/bolt-server/conf.d/bolt-server.conf`

**Local Config**: `~/.puppetlabs/bolt-server.conf`

**Options**
- `host`: String, *optional* - Hostname for server (default "127.0.0.1").
- `port`: Integer, *optional* - The port the bolt server will run on (default 62658).
- `ssl-cert`: String, *required* - Path to the cert file.
- `ssl-key`: String, *required* - Path to the key file.
- `ssl-ca-cert`: String, *required* - Path to the ca cert file.
- `ssl-cipher-suites`: Array, *optional* - TLS cipher suites in order of preference ([default](#default-ssl-cipher-suites)).
- `loglevel`: String, *optional* - Bolt log level, acceptable values are `debug`, `info`, `notice`, `warn`, `error` (default `notice`).
- `logfile`: String, *optional* - Path to log file.
- `whitelist`: Array, *optional* - A list of hosts which can connect to pe-bolt-server.
- `concurrency`: Integer, *optional* - The maximum number of server threads (default `100`).

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
    "hostname": "linux_target.net",
    "user": "marauder",
    "password": "I solemnly swear that I am up to no good",
    "host-key-check": false,
    "run-as": "george_weasley"
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
      "filename": "echo.sh",
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
    "hostname": "windows_target.net",
    "user": "Administrator",
    "password": "Secret",
    "ssl": false,
    "ssl-verify": false
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
      "filename": "echo.ps1",
      "file_content": "cGFyYW0gKCRtZXNzYWdlKQpXcml0ZS1PdXRwdXQgIiRtZXNzYWdlIg==\n"
    }
  },
  "parameters": {
    "message": "Hello world"
  }
}
```

### SSH Target Object
The Target is a JSON object. See the [schema](../lib/bolt_ext/schemas/ssh-run_task.json)

### WinRM Target Object
The Target is a JSON object. See the [schema](../lib/bolt_ext/schemas/winrm-run_task.json)

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

- `description`: String, *optional* - The task description from it's metadata.
- `parameters`: Object, *optional* - A JSON object whose keys are parameter names, and whose values are JSON objects with 2 keys:
    - `description`: String, *optional* - The parameter description.
    - `type`: String, *optional* - The type the parameter should accept.

#### File
**NOTE**: We plan to eventually get this information directly from puppetserver

The task file and it's metadata. This is a JSON object that includes the following keys:
- `filename`: String, *required* - The name of the file the task is in. Note: Will reject any string that contains `/` if using SSH transport, and any string that contains `\` if using WinRM.
- `file_content`: String, *required* - Task's base64 encoded file content.

For example:
```
{
  "task": {
    "name": "echo",
    "metadata": {
      "description": "Echo a message",
      "parameters": {
        "message": "Default string"
      }
    },
    "file": {
      "filename": "echo.sh",
      "file_content": "IyEvdXNyL2Jpbi9lbnYgYmFzaAplY2hvICRQVF9tZXNzYWdlCg==\n"
    }
  }
}
```

### Response
If the task runs the response will have status 200.
The response will be a standard bolt Result JSON object.

## Install from Source

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
curl -O http://builds.delivery.puppetlabs.net/pe-bolt-server/0.21.8/repos/deb/xenial/pe-bolt-server_0.21.8-1xenial_amd64.deb
dpkg -i pe-bolt-server_0.21.8-1xenial_amd64.deb
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
    "hostname": "xlr5bknywm58t94.delivery.puppetlabs.net",
    "user": "root",
    "private-key-content": [Contents of ssh private key as a string],
    "host-key-check": false
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
      "filename": "echo.sh",
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
curl -X POST -H "Content-Type: application/json" -d @request.json --cert /etc/puppetlabs/bolt-server/ssl/cert.pem --key /etc/puppetlabs/bolt-server/ssl/key.pem -k https://xlr5bknywm58t94.delivery.puppetlabs.net:62658/ssh/run_task
```
10. Expected Output
```
{"node":"xlr5bknywm58t94.delivery.puppetlabs.net",
"status":"success",
"result":{"_output":"Hello world\n"}}
```
