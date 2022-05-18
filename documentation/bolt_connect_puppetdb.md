# Connecting Bolt to PuppetDB

Configure Bolt to connect to PuppetDB.

## PuppetDB authorization

Bolt can authenticate with PuppetDB through an SSL client certificate or a PE
RBAC token.

## Client certificate

Add the certname for the certificate you want to authenticate with
to `/etc/puppetlabs/puppetdb/certificate-allowlist`. This certificate has full
access to all PuppetDB API endpoints and can read all data, push new data, or
run commands on PuppetDB. To test the certificate you run the following curl
command.

```
curl -X GET $SERVER_URL/pdb/query/v4 --data-urlencode 'query=nodes[certname] {}' --cert $CERT_PATH --key $KEY_PATH --cacert $CACERT_PATH
```

## Token-based authentication with PE RBAC token

If you use Puppet Enterprise you can grant more restricted access to PuppetDB
with a PE role-based access control (RBAC) token.

1.  In PE, verify you are assigned to a role that has the appropriate RBAC
    permission. It needs the permission type **Nodes** and the action **View
    node data from PuppetDB**.

2.  From the command line, run `puppet-access login --lifetime <TIME PERIOD>`.

3.  When prompted, enter the same username and password that you use to log into
    the PE console. The token is generated and stored in a file for later use.
    The default location for storing the token is ~/.puppetlabs/token. 

4.  Verify that authentication is working with the following curl command.

```
curl -X GET https://$SERVER_URL/pdb/query/v4 --data-urlencode 'query=nodes[certname] {}' -H "X-Authentication: `cat ~/.puppetlabs/token`" --cacert $CACERT_PATH
```


## Configuration

To configure the Bolt PuppetDB client, add a `puppetdb` section to your [Bolt
config](configuring_bolt.md) with the following values:

| Option | Type | Description |
| --- | --- | --- |
| `cacert` | `String` | The path to the CA certificate for PuppetDB. |
| `connect_timeout` | `Integer` | How long to wait in seconds when establishing connections with PuppetDB. |
| `read_timeout` | `Integer` | How long to wait in seconds for a response from PuppetDB. |
| `server_urls` | `Array` | An array of strings containing the PuppetDB host to connect to. Include the protocol `https` and the port, which is usually `8081`. For example, `https://my-puppetdb-server.example.com:8081`. The Bolt PuppetDB client attempts to connect to each host in the list until it makes a successful connection. |

If you are using certificate authentication also set:

| Option | Type | Description |
| --- | --- | --- |
| `cert` | `String` | The path to the client certificate file to use for authentication. |
| `key` | `String` | The private key for the certificate. |

If you are using a PE RBAC token set:

| Option | Type | Description |
| --- | --- | --- |
| `token` | `String` | The path to the PE RBAC token. |

For example, to use certificate authentication:

```
puppetdb:
  server_urls: ["https://puppet.example.com:8081"]
  cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
  cert: /etc/puppetlabs/puppet/ssl/certs/my-host.example.com.pem
  key: /etc/puppetlabs/puppet/ssl/private_keys/my-host.example.com.pem
```

If PE is installed and PuppetDB is not defined in a config file, Bolt uses the
PuppetDB config defined in either:
- `$HOME/.puppetlabs/client-tools/puppetdb.conf` or
- `/etc/puppetlabs/client-tools/puppetdb.conf` (Windows:
`%CSIDL_COMMON_APPDATA%\PuppetLabs\client-tools\puppetdb.conf`).

**Important:** Bolt does not merge config files into a conf.d format the way
that pe-client-tools does.

To use PE RBAC authentication:

```
puppetdb:
  server_urls: ["https://puppet.example.com:8081"]
  cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
  token: ~/.puppetlabs/token
```

## Configuring multiple PuppetDB instances

The Bolt PuppetDB Client supports connections to multiple PuppetDB instances. To
configure multiple PuppetDB instances, add the `puppetdb-instances` section to
your [Bolt config](configuring_bolt.md).

The `puppetdb-instances` section is a map of configuration, where each key is the
name of the PuppetDB instance and values are the configuration for the instance.
Each instance supports the same configuration as the `puppetdb` section.

For example, to configure a named instance that uses certificate authentication
and a second instance that uses PE RBAC authentication:

```yaml
puppetdb-instances:
  instance-1:
    server_urls: ["https://instance-1.example.com:8081"]
    cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
    cert: /etc/puppetlabs/puppet/ssl/certs/my-host.example.com.pem
    key: /etc/puppetlabs/puppet/ssl/private_keys/my-host.example.com.pem
  instance-2:
    server_urls: ["https://instance-2.example.com:8081"]
    cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
    token: ~/.puppetlabs/token
```

## Connecting to a named PuppetDB instance

When using Bolt features that connect to PuppetDB, you can specify a named
instance to connect to if you have configured multiple PuppetDB instances
under the `puppetdb-instances` section.

To specify a PuppetDB instance to the `puppetdb_*` plan functions, pass the
PuppetDB instance name as the last positional argument to the function:

```puppet
plan example() {
  puppetdb_fact(['host.example.com'], 'instance-1')
}
```

To specify a PuppetDB instance to the `apply` plan function, use the `_puppetdb`
option:

```puppet
plan example() {
  apply('localhost', '_puppetdb' => 'instance-1') {
    notice('Hello, world!')
  }
}
```

To specify a PuppetDB instance to the `puppetdb` plugin, use the `instance`
option:

```yaml
targets:
  _plugin: puppetdb
  query: "inventory[certname] { facts.osfamily = 'RedHat' }"
  instance: instance-1
```

## Specifying a default PuppetDB instance

When you do not specify a named PuppetDB instance, the Bolt PuppetDB client
connects to the default PuppetDB instance. Typically, this is the PuppetDB
instance configured under the `puppetdb` section.

For example, the following `bolt-project.yaml` configures a default
PuppetDB instance and two named PuppetDB instances:

```yaml
puppetdb:
    server_urls: ["https://puppetdb.example.com:8081"]
    cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
    token: ~/.puppetlabs/token

puppetdb-instances:
  instance-1:
    server_urls: ["https://instance-1.example.com:8081"]
    cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
    cert: /etc/puppetlabs/puppet/ssl/certs/my-host.example.com.pem
    key: /etc/puppetlabs/puppet/ssl/private_keys/my-host.example.com.pem
  instance-2:
    server_urls: ["https://instance-2.example.com:8081"]
    cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
    token: ~/.puppetlabs/token
```

The following plan invokes the `puppetdb_fact` twice. The first invocation
connects to the default PuppetDB instance (configured under the `puppetdb`
section), while the second invocation connects to `instance-2` (configured
under the `puppetdb-instances` section).

```puppet
plan example() {
  # Connects to https://puppetdb.example.com:8081
  puppetdb_fact(['host-1.example.com'])

  # Connects to https://instance-2.example.com:8081
  puppetdb_fact(['host-2.example.com'], 'instance-2')
}
```

Bolt allows you to change the default PuppetDB instance to a named instance
each time you run a command. This results in Bolt connecting to the named
instance whenever a named instance is not specified.

To specify a named instance as the default instance, use the `puppetdb`
command-line option:

_\*nix shell command_

```shell
$ bolt plan run example --puppetdb instance-1
```

_PowerShell cmdlet_

```powershell
> Invoke-BoltPlan -Name example -PuppetDB instance-1
```

When running the example from above, the first invocation of the
`puppetdb_fact` function will now connect to the named PuppetDB instance
`instance-1`.

## Testing

You can test your configuration with the following plan, which returns a list of
all nodes in PuppetDB.

```
plan pdb_test {
  return(puppetdb_query("nodes[certname] {}"))
}
```

## Practical Usage

In practice, it is common to extract inventory from PuppetDB dynamically to use
in a plan. The following is an example using the `puppetdb_query()` function
directly. This method works but requires data munging to be effective.

```
plan puppetdb_query_targets {
  # query PuppetDB for a list of node certnames
  # this returns an array of objects, each object containing a "certname" parameter:
  # [ {"certname": "node1"}, {"certname": "node2"} ]
  $query_results = puppetdb_query("nodes[certname] {}")
  
  # since puppetdb_query() returns the JSON results from the API call, we need to transform this
  # data into Targets to use it in one of the run_*() functions.
  # extract the "certname" values, so now we have an array of hostnames
  $certnames = $query_results.map |$r| { $r['certname'] }
  
  # transform the arary of certnames into an array of Targets
  $targets = get_targets($certnames)
  
  # gather facts about all of the nodes
  run_task('facts', $targets)
}
```

Alternatively, the [PuppetDB inventory plugin](using_plugins.md) can be used to
execute a query and return Targets. This avoids the data munging from the
previous example:

```
plan puppetdb_plugin_targets {
  # Resolves "references" from the PuppetDB inventory plugin using the specified PQL query.
  $refs = {
    '_plugin' => 'puppetdb',
    'query'   => 'nodes[certname] {}',
  }
  $references = resolve_references($refs)
  
  # maps the results into a list of Target objects
  $targets = $references.map |$r| { Target.new($r) }
  
  # gather facts about all of the nodes
  run_task('facts', $targets)
}
```
