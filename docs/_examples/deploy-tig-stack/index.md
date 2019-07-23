---
title: Deploying a TIG Stack
description: This example shows how to use Bolt to configure and deploy metrics visualization using Telegraf, InfluxDB, and Grafana, all via existing Puppet Modules.
---

```
project/
└── Boltdir
    ├── hiera.yaml
    ├── inventory.yaml
    ├── Puppetfile
    └── site
        └── tig
            ├── manifests
            |   ├── dashboard.pp
            |   ├── params.pp
            |   └── telegraf.pp
            ├── plans
            |   └── init.pp
            └── templates
                └── dashboards
                    └── telegraf.json
```

## Provisioning Nodes

To follow this example and deploy the TIG stack you'll need at least two nodes - one for the dashboard and one or more for the agents. You can use existing nodes in your system or create them using the provided `Vagrantfile`.

```shell
{% include_relative Boltdir/Vagrantfile %}
```

You should then generate the SSH configuration for both nodes, which will automatically be picked up by Bolt. Once you've generated SSH configuration, make sure you can SSH into the nodes.

```shell
mkdir ~/.ssh
vagrant ssh-config | sed /StrictHostKeyChecking/d | sed /UserKnownHostsFile/d >> ~/.ssh/config
```

## Installing Modules from a Puppetfile

Before you can use Bolt to install modules, you must first create a Puppetfile. A Puppetfile is a formatted text file that contains a list of modules and their versions. It can include modules from the Puppet Forge or a Git repository.

This example has a Puppetfile with the following list of modules:

```puppet
{% include_relative Boltdir/Puppetfile -%}
```

To install the modules in the Puppetfile, run the following command:

```shell
bolt puppetfile install
```

The `puppet-telegraf` module requires the `toml-rb` gem, so make sure to install it as well.

```shell
/opt/puppetlabs/bolt/bin/gem install toml-rb
```

## Creating the Inventory File

Next, you'll create an inventory file to specify which nodes to use as part of the plan. If you are using existing nodes in your system, replace `node0` and `node1` with your own nodes.

```yaml
{% include_relative Boltdir/inventory.yaml -%}
```

## Examining the Plan

Now that all of the required modules have been installed and the inventory file is populated with nodes, we'll take a look at the plan that will deploy the metrics visualization. In the `site/` directory, you'll find the following plan:

```puppet
{% include_relative Boltdir/site/tig/plans/init.pp -%}
```

Plans let you compose different tasks together in meaningful ways and can have multiple steps, compute input, and process output. The first step in this plan installs the `puppet-agent` package and collects facts from each of the nodes in the inventory file.

Next, the first apply block will apply the `dashboard` manifest, which installs and configures both Grafana and InfluxDB. This manifest inherits a separate class called `tig::params`, which contains configuration parameters.

```puppet
{% include_relative Boltdir/site/tig/manifests/dashboard.pp -%}
```

```puppet
{% include_relative Boltdir/site/tig/manifests/params.pp -%}
```

Credentials for signing into each service can be kept in a separate location so they aren't part of the manifest code. This example stores this information in `data/common.yaml`:

```yaml
{% include_relative Boltdir/data/common.yaml -%}
```

The second apply block will apply the `telegraf` manifest, which installs and configures Telegraf, on each of the agents. Similar to the `dashboard` manifest, it will also inherit the `tig::params` class, which contains configuration parameters.

```puppet
{% include_relative Boltdir/site/tig/manifests/telegraf.pp -%}
```

The last step in the plan returns results that you can use in other plans or save for use outside of Bolt. In this example it simply returns the address for the Grafana dashboard.

## Running the Plan

You've downloaded and installed the required modules from the Puppet Forge, populated the inventory file with nodes, and set up configuration parameters in the `dashboard` and `telegraf` manifests. All that's left is to run the plan.

```shell
bolt plan run tig
```

The result of running the plan will look like this:

```
Starting: plan tig
Starting: install puppet and gather facts on node0, node1
Finished: install puppet and gather facts with 0 failures in 47.67 sec
Starting: apply catalog on node0
Finished: apply catalog with 0 failures in 65.3 sec
Starting: apply catalog on node0, node1
Finished: apply catalog with 0 failures in 22.64 sec
Finished: plan tig in 135.65 sec
{
  "grafana_dashboard": "http://10.0.0.100:8080"
}
```

Success! If you navigate to the address in the plan's result you'll find the Grafana dashboard and be able to sign in using the credentials you used when configuring the dashboard. In this example the user is `bolt` and the password is `boltIsAwesome`.
