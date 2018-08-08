# Connecting Bolt to PuppetDB 

Configure Bolt to connect to PuppetDB.

## PuppetDB Authorization

Bolt can authenticate with PuppetDB through an SSL client certificate or a PE RBAC token.

## Client Certificate

Add the certname for the certificate you want to authenticate with to /`etc/puppetlabs/puppetdb/certificate-whitelist`. This certificate has full access to all PuppetDB API endpoints and can read all data, push new data, or run commands on PuppetDB. To test the certificate you run the following curl command.

```
curl -X GET $SERVER_URL/pdb/query/v4 --data-urlencode 'query=nodes[certname] {}' --cert $CERT_PATH --key $KEY_PATH --cacert $CACERT_PATH
```

## Token-based authentication PE RBAC Token

If you use Puppet Enterprise you can grant more restricted access to PuppetDB with a PE role-based access control \(RBAC\) token.

1.  In PE, verify you are assigned to a role that has the appropriate RBAC permission. It needs the permission type **Nodes** and the action **View node data from PuppetDB**.

2.  From the command line, run `puppet-access login --lifetime <TIME PERIOD>`.

3.  When prompted, enter the same username and password that you use to log into the PE console. The token is generated and stored in a file for later use. The default location for storing the token is ~/.puppetlabs/token. 

4.  Verify that authentication is working with the following curl command.

```
curl -X GET https://$SERVER_URL/pdb/query/v4 --data-urlencode 'query=nodes[certname] {}' -H "X-Authentication: `cat ~/.puppetlabs/token`" --cacert $CACERT_PATH
```


## Configuration

To configure the Bolt PuppetDB client, add a `puppetdb` section to `~/.puppetlabs/bolt.yml` with the following values:

-    `server-urls`: An array containing the PuppetDB host to connect to. This should include the protocol `https` and the port is usually `8081`. For example `https://my-master.example.com:8081` 
-    `cacert`: The path the ca certificate for puppetdb

If you are using certificate authentication also set:

-    `cert`: The path to the client certificate file to use for authentication
-    `key`: The private key for that certificate

If you are using a PE RBAC token set:

-    `token`: The path to the PE RBAC Token.

For example, to use certificate authentication:

```
puppetdb:
  server_urls: ["https://puppet.example.com:8081"]
  cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
  cert: /etc/puppetlabs/puppet/ssl/certs/my-host.example.com.pem
  key: /etc/puppetlabs/puppet/ssl/private_keys/my-host.example.com.pem
```

If PE is installed and PuppetDB is not defined in a config file, Bolt uses the PuppetDB config defined in either: `$HOME/.puppetlabs/client-tools/puppetdb.conf`or `/etc/puppetlabs/client-tools/puppetdb.conf` \(Windows: `C:\ProgramData\PuppetLabs\client-tools\puppetdb.conf`\).

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

**Parent topic:** [Configuring Bolt](configuring_bolt.md)

