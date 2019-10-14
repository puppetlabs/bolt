# Generating inventory files

**DEPRECATED** This command has been deprecated in favor of the [puppetdb inventory plugin](https://puppet.com/docs/bolt/latest/using_plugins.html#puppetdb)

Use the `bolt-inventory-pdb` script to generate inventory files based on PuppetDB queries.

## Usage

The `bolt-inventory-pdb` script accepts a single argument: the path of the source file used to generate the inventory file. It queries PuppetDB to resolve node lists and prints inventory yaml output to stdout or to a file you specify with the `-o` flag.

```
bolt-inventory-pdb pdb.yaml -o ~/.puppetlabs/bolt/inventory.yaml
```

For full usage information, type `bolt-inventory-pdb --help`.

## Configuration

The `bolt-inventory-pdb` script uses the configuration file `puppetdb.conf`, which is stored at:

-   ***nix systems** `$HOME/.puppetlabs/client-tools/puppetdb.conf`
-   **Windows** `%USERPROFILE%\.puppetlabs\client-tools\puppetdb.conf`

**Note:** The precedence used to load puppetdb config is:

1.  `configfile` (optionally specified with `--configfile`)
1.  `$HOME/.puppetlabs/client-tools/puppetdb.conf`
1.  `/etc/puppetlabs/client-tools/puppetdb.conf` (Windows: `C:\ProgramData\PuppetLabs\client-tools\puppetdb.conf`)

`bolt-inventory-pdb` configuration can also be passed on the command line. These settings are required:

-   `--cacert` The path for the certification authority (CA) certificate.
    - ***nix systems** `/etc/puppetlabs/puppet/ssl/certs/ca.pem`
    - **Windows** `C:\\ProgramData\\PuppetLabs\\puppet\\etc\\ssl\\certs\\ca.pem`
-   `--url` The URL of your PuppetDB server.

One of these authentication methods is required:

-   `--token-file` The path to the PE authorization token.
-   `--cert` and `--key` The path to a client ssl certificate, and the private key for that certificate.

```
bolt-inventory-pdb pdb.yaml -o myfile.yaml --token-file ~/mytoken --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem --url https://<PUPPETDB_HOST>:8081
```

## File format

The `bolt-inventory-pdb` tool generates an inventory file from a source yaml file. This file has the same format as the inventory file, except instead of nodes keys it has query keys. The query is a PuppetDB query in either [Puppet Query Language \(PQL\)](https://puppet.com/docs/puppetdb/latest/api/query/v4/pql.html) or [PuppetDB AST](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html) syntax. When `bolt-inventory-pdb` runs it makes queries against PuppetDB and creates a nodes item for each group. This is an example of a file that adds all nodes to the top-level group, creates a "windows" group configured to use the WinRM transport and a "basil" group for nodes with "basil" in the certname.

```yaml
query: "nodes[certname] {}"
groups:
  - name: windows
     query: "inventory[certname] { facts.osfamily = 'windows' }"
     config:
     transport: winrm
  - name: basil
    query: "nodes[certname] { certname ~ '^basil' }"
```
