# Connecting Bolt to PuppetDB

Configure Bolt to connect to PuppetDB.

## PuppetDB authorization

Bolt can authenticate with PuppetDB through an SSL client certificate or a PE RBAC token.

## Client certificate

Add the certname for the certificate you want to authenticate with to `/etc/puppetlabs/puppetdb/certificate-whitelist`. This certificate has full access to all PuppetDB API endpoints and can read all data, push new data, or run commands on PuppetDB. To test the certificate you run the following curl command.

```
curl -X GET $SERVER_URL/pdb/query/v4 --data-urlencode 'query=nodes[certname] {}' --cert $CERT_PATH --key $KEY_PATH --cacert $CACERT_PATH
```

## Token-based authentication with PE RBAC token

If you use Puppet Enterprise you can grant more restricted access to PuppetDB with a PE role-based access control (RBAC) token.

1.  In PE, verify you are assigned to a role that has the appropriate RBAC permission. It needs the permission type **Nodes** and the action **View node data from PuppetDB**.

2.  From the command line, run `puppet-access login --lifetime <TIME PERIOD>`.

3.  When prompted, enter the same username and password that you use to log into the PE console. The token is generated and stored in a file for later use. The default location for storing the token is ~/.puppetlabs/token. 

4.  Verify that authentication is working with the following curl command.

```
curl -X GET https://$SERVER_URL/pdb/query/v4 --data-urlencode 'query=nodes[certname] {}' -H "X-Authentication: `cat ~/.puppetlabs/token`" --cacert $CACERT_PATH
```


## Configuration

To configure the Bolt PuppetDB client, add a `puppetdb` section to your [Bolt config](configuring_bolt.md) with the following values:

-   `server_urls`: An array containing the PuppetDB host to connect to. Include the protocol `https` and the port, which is usually `8081`. For example, `https://my-master.example.com:8081`.
-   `cacert`: The path to the ca certificate for PuppetDB.

If you are using certificate authentication also set:

-   `cert`: The path to the client certificate file to use for authentication
-   `key`: The private key for that certificate

If you are using a PE RBAC token set:

-   `token`: The path to the PE RBAC Token.

For example, to use certificate authentication:

```
puppetdb:
  server_urls: ["https://puppet.example.com:8081"]
  cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
  cert: /etc/puppetlabs/puppet/ssl/certs/my-host.example.com.pem
  key: /etc/puppetlabs/puppet/ssl/private_keys/my-host.example.com.pem
```

If PE is installed and PuppetDB is not defined in a config file, Bolt uses the PuppetDB config defined in either: `$HOME/.puppetlabs/client-tools/puppetdb.conf`or `/etc/puppetlabs/client-tools/puppetdb.conf` (Windows: `%CSIDL_COMMON_APPDATA%\PuppetLabs\client-tools\puppetdb.conf`).

**Important:** Bolt does not merge config files into a conf.d format the way that pe-client-tools does.

To use PE RBAC authentication:

```
puppetdb:
  server_urls: ["https://puppet.example.com:8081"]
  cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
  token: ~/.puppetlabs/token
```

## Testing

You can test your configuration with the following plan, which returns a list of all nodes in PuppetDB.

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

Alternatively, the [PuppetDB inventory plugin](using_plugins.md) can be used to execute
a query and return Targets. This avoids the data munging from the previous example:

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
