
# Configuring PuppetDB

Configure bolt to connect to PuppetDB

## Why

- [Generate an Inventory File](inventory_file_generating.md)
- [Discover Facts for Targets](writing_plans.md#collect-facts-from-puppetdb)
- [Make Queries in Plans](writing_plans.md#puppetdb_query)

## PuppetDB Authorization

Bolt can authenticate with PuppetDB through an ssl client certificate or a PE
RBAC token.

### Client Certificate

Add the certname for the certificate you want to authenticate with to
`/etc/puppetlabs/puppetdb/certificate-whitelist`. This certificate will have
full access to all PuppetDB API endpoints and can read all data, push new data
or run commands on PuppetDB. To test the certificate you can run the following
curl command.

```
curl -X GET $SERVER_URL/pdb/query/v4 --data-urlencode 'query=nodes[certname] {}' --cert $CERT_PATH --key $KEY_PATH --cacert $CACERT_PATH
```

### PE RBAC Token

If you use PE you can grant more restricted access to PuppetDB with a PE RBAC
token. First, make sure the user you will log in as has the 'View node data from
PuppetDB' permission. Then, login that user with `puppet-access`, this will save
the token `~/.puppetlabs/token`. You can verify that authentication is working
with the following curl command.

```
curl -X GET https://$SERVER_URL/pdb/query/v4 --data-urlencode 'query=nodes[certname] {}' -H "X-Authentication: `cat ~/.puppetlabs/token`" --cacert $CACERT_PATH
```

## Configuration

To configure the bolt puppetdb client add a `puppetdb` section with the following values
- `server-urls`: An array containing the PuppetDB host to connect to. This should include the protocol `https` and the port usually `8081`. For example `https://my-master.example.com:8081`
- `cacert`: The path the ca certificate for puppetdb

If you're using certificate auth also set:
- `cert`: The path to the client certificate file to use for authentication
- `key`: The private key for that certificate

If your using a PE RBAC token set:
- `token`: The path to the PE RBAC Token.

For example to use certificate auth:
```yaml
puppetdb:
  server_urls: ["https://puppet.example.com:8081"]
  cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
  cert: /etc/puppetlabs/puppet/ssl/certs/my-host.example.com.pem
  key: /etc/puppetlabs/puppet/ssl/private_keys/my-host.example.com.pem
```
If Puppet Enterprise is installed and puppetdb is not defined in a configfile bolt will default to use puppetdb config defined in either`$HOME/.puppetlabs/client-tools/puppetdb.conf` or `/etc/puppetlabs/client-tools/puppetdb.conf` (`C:\ProgramData\PuppetLabs\client-tools\puppetdb.conf` if windows OS).
> **Note**: Bolt **will not** merge config files into a conf.d format the way that pe-client-tools will.

To use PE RBAC auth
```yaml
puppetdb:
  server_urls: ["https://puppet.example.com:8081"]
  cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
  token: ~/.puppetlabs/token
```

## Testing

You can test your configuration with the following plan which will return a list of all nodes in puppetdb.

```puppet
plan pdb_test {
  return(puppetdb_query("nodes[certname] {}"))
}
