# Bolt Server 

## Overview
Bolt server provides a service to run bolt tasks over SSH and WinRM. This service is exposed via an API as described in this document. Bolt server works as a standalone service, and is available in PE Johnson and greater as `pe-bolt-server`.

## Configuration
Bolt server can be configured by defining content in HOCON format at one of the following expected configuration file path locations.

**Global Config**: `/etc/puppetlabs/bolt-server/conf.d/bolt-server.conf`

**Local Config**: `~/.puppetlabs/bolt-server.conf`

**Options**
- `port`: Integer, *optional* - The port the bolt server will run on (default 8144)
- `ssl-cert`: String, *required* - Path to the cert file.
- `ssl-key`: String, *required* - Path to the key file.
- `ssl-ca-cert`: String, *required* - Path to the ca cert file.

**Example**
```
bolt-server: {
    port: 8144
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

### Task Object
The Task be a JSON object. The following keys are available:
- `name`: String, *required* - The name of the task.
- `metadata`: String, *optional* - The contents of the task's metadata.json file. 
- `file_content`: String, *required* - Task's base64 encoded file content.

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
    "file_content": "IyEvdXNyL2Jpbi9lbnYgYmFzaAplY2hvICRQVF9tZXNzYWdlCg==\n"
  },
  "parameters": {
    "message": "Hello world"
  }
}
```
9. Make request
```
curl -X POST -H "Content-Type: application/json" -d @request.json -E /etc/puppetlabs/bolt-server/ssl/$HOSTNAME.cert.pem --key /etc/puppetlabs/bolt-server/ssl/$HOSTNAME.key.pem -k https://0.0.0.0:8144/ssh/run_task

```
10. Expected Output
```
{ "node":"juvct8xnyr2ihvm.delivery.puppetlabs.net",
  "status":"success",
  "result": { "_output":"Hello world\n" }
}
```
