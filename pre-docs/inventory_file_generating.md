
# Generating inventory files

Use the bolt-inventory-pdb script to generate inventory files based on PuppetDB queries.


## Usage

The `bolt-inventory-pdb` script accepts a single argument: the path of the source
file used to generate the inventory file. It queries PuppetDB to resolve node
lists and prints inventory yaml output to stdout or to a file you specify with
the `-o` flag.

```bash
bolt-inventory-pdb pdb.yaml -o ~/.puppetlabs/bolt/inventory.yaml
```
For full usage information, type bolt-inventory-pdb --help.


## Configuration

The bolt-inventory-pdb script uses the configuration file puppetdb.conf, which
is stored at:

*nix systems `$HOME/.puppetlabs/client-tools/puppetdb.conf`

Windows `%USERPROFILE%\.puppetlabs\client-tools\puppetdb.conf`

> Note: The presedence used to load puppetdb config is
> 1. configfile (optionally specified with --configfile)
> 2. $HOME/.puppetlabs/client-tools/puppetdb.conf
> 3. /etc/puppetlabs/client-tools/puppetdb.conf (windows: C:\ProgramData\PuppetLabs\client-tools\puppetdb.conf)


`bolt-inventory-pdb` requires the following file settings:

- `--token-file` The path to the PE Authorization token.
- `--cacert` The path for the certification authority (CA) certificate.
  *nix sytems `-/etc/puppetlabs/puppet/ssl/certs/ca.pem`
  Windows - C:\ProgramData\PuppetLabs\puppet\etc\ssl\certs\ca.pem`
- `--url` The URL of your PuppetDB server.


```bash
$ bolt-inventory-pdb pdb.yaml -o myfile.yaml --token-file ~/mytoken --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem --url  https://<PUPPETDB_HOST>:8081

```

## File format
The `bolt-inventory-pdb` tool generates an inventory file from a source yaml
file. This file has the same format as the inventory file except instead of
nodes keys it has query keys. The query should be a PuppetDB query in either
Puppet Query Language (PQL) or AST syntax. When `bolt-inventory-pdb` runs it
makes queries against PuppetDB and creates a nodes item for each group. This is
an example of a file that adds all nodes to the top-level group, creates a
windows group configured to use the winrm transport and a basil group for nodes
with basil in the certname.

```yaml
---
query: "nodes[certname] {}"
groups:
- name: windows
query: "inventory[certname] { facts.osfamily = 'windows' }"
config:
transport: winrm
- name: basil
query: "nodes[certname] { certname ~ '^basil' }"
```
