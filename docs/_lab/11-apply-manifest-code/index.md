---
title: Applying Manifest Code With Bolt
difficulty: Advanced
time: Approximately 20 minutes
---

In this exercise you will further explore Bolt Plans by using the `apply` keyword to leverage existing content from the [Puppet Forge](https://forge.puppet.com/).

You can read more about using bolt `apply` in Masterless Workflows in a [Blog Post](https://puppet.com/blog/introducing-masterless-puppet-bolt) written by Bolt developer Michael Smith. 

You will deploy two web servers and a load balancer to distribute the traffic evenly between them with the following steps:
1. Build a project specific configuration using a `Boltdir`.
1. Download useful module content from the Puppet forge. 
1. Write a Puppet Class to abstract the configuration of an Nginx web server. 
1. Write a Bolt Plan to `apply` puppet code and orchestrate the deployment of a static website. 

# Prerequisites

For the following exercises you should have `bolt` Docker and docker-compose installed. The following guides will help:

1. [Acquiring Nodes](../02-acquiring-nodes)
1. [Writing Advanced Plans](../09-writing-advanced-plans)

# Acquire nodes

This lesson requires three nodes. You can use the [docker-compose.yml](docker-compose.yml) file in this repository to provision the nodes necessary for this exercise. 

Nodes can be obtained with the `docker-compose up -d` command.

You can verify nodes are created with `docker ps`
```
8b7f33d8fde4        lab_node            "/usr/sbin/sshd -D"   About an hour ago   Up About an hour    0.0.0.0:20023->22/tcp                          11applymanifestcode_server_1_1
90f6abe8dfc8        lab_node            "/usr/sbin/sshd -D"   About an hour ago   Up About an hour    0.0.0.0:20024->22/tcp                          11applymanifestcode_server_2_1
26c47f8c4bad        lab_node            "/usr/sbin/sshd -D"   About an hour ago   Up About an hour    0.0.0.0:20022->22/tcp, 0.0.0.0:20080->80/tcp   lb
```

# Build a Boltdir

By default `$HOME/.puppetlabs/bolt/` is the base directory for user-supplied data such as the configuration and inventory files. It is effectively the default `Boltdir`. 
You may find it useful to maintain a project specific `Boltdir`. When you commit a `Boltdir` to a project you can share Bolt configuration and code between users.

Bolt will search for a `Boltdir` in parent directories of the directory from which it was run.

## Inventory

Build an inventory to organize provisioned nodes. This will be the first configuration file in our new project specific `Boltdir`. 

**Note**: Example outputs in the lab are for nodes provisioned with Docker. 

### Docker nodes
If you provisioned your nodes with the docker-compose file provided with this exercise save the following in `Boltdir/inventory.yaml`.

```yaml
{% include_relative Boltdir/inventory.yaml -%}
```

Make sure your inventory is configured correctly and you can connect to all nodes. Run from within the project Boltdir:

```bash
bolt command run 'echo hi' -n all
```

Expected output

```plain
Started on 0.0.0.0...
Started on localhost...
Started on 127.0.0.1...
Finished on localhost:
  STDOUT:
    hi
Finished on 0.0.0.0:
  STDOUT:
    hi
Finished on 127.0.0.1:
  STDOUT:
    hi
Successful on 3 nodes: 0.0.0.0:20022,127.0.0.1,localhost
Ran on 3 nodes in 0.20 seconds
```

## Module Content

In order to install module content from the forge Bolt uses a `Puppetfile`. See [Puppetfile Documentation](https://puppet.com/docs/pe/latest/puppetfile.html) for more information. 

Save the following `Puppetfile` that describes the Puppet Forge content to be installed in the project `Boltdir`. 

```ruby
{% include_relative Boltdir/Puppetfile -%}
```

From within the `Boltdir` install the Forge content with the following Bolt command:

```shell
bolt puppetfile install
```

Confirm that a `modules` directory has been created in the project `Boltdir`. 

## Write profile module

Now that you have downloaded existing modules it is time to write your own module content. Custom module content not managed by the project `Puppetfile` belongs in a `site` directory in the `Boltdir`. After creating a `Boltdir/site` directory create a new directory called `profiles`. The `profiles` module will be our own custom module. 

Start by abstracting the Nginx setup by writing a Puppet Class. Puppet code belongs in a subdirectory of our module called `manifests`. Save the following class definition in `Boltdir/site/profiles/manifests/server.pp`. 

If you are new to Puppet writing puppet code check out [these learning resources](https://learn.puppet.com/). The Learning VM is especially helpful for getting up to speed with Puppet.

```puppet
{% include_relative Boltdir/site/profiles/manifests/server.pp -%}
```

**Note**: Vox Pupuli maintains an [nginx module](https://forge.puppet.com/puppet/nginx/readme) that you could swap in for our simple server class to manage more complex nginx configuration.

Now we will write a Plan to utilize the server class. 

As we have seen in the lab, plan code belongs in the `plans` subdirectory. Save the following to `Boltdir/site/profiles/plans/nginx_install.pp`.

Take note of the following features of the plan:

1. This plan has three parameters, the server nodes, the load balancer nodes and a string to be statically served by our load balanced Nginx servers. 
1. Notice the `apply_prep` function call. `apply_prep` is used to install packages needed by apply on remote nodes as well as to gather facts about the nodes.
1. The first apply block configures the Nginx servers. The site content is defined by default to be "Hello from [node name]" where node name is a fact gathered by `apply_prep`. The `site_content` parameter can be configured in the bolt plan invocation. 
1. The second apply block uses information about the Nginx servers to configure a load balancer to direct traffic between the two servers. 

```puppet
{% include_relative Boltdir/site/profiles/plans/nginx_install.pp -%}
```

Verify the `nginx_install` plan is available to run using `bolt plan show`. You should see an output similar to: 

```
aggregate::count
aggregate::nodes
canary
facts
facts::info
profiles::nginx_install
puppetdb_fact
```

Now you are ready to execute the plan. 

```bash
bolt plan run profiles::nginx_install servers=servers lb=lb
```

Expected output

```
Starting: plan profiles::nginx_install
Starting: install puppet and gather facts on 127.0.0.1, localhost, 0.0.0.0:20022
Finished: install puppet and gather facts with 0 failures in 3.84 sec
Starting: apply catalog on 127.0.0.1, localhost
Finished: apply catalog with 0 failures in 6.72 sec
Starting: apply catalog on 0.0.0.0:20022
0.0.0.0:20022: Scope(Haproxy::Config[haproxy]): haproxy: The $merge_options parameter will default to true in the next major release. Please review the documentation regarding the implications.
Finished: apply catalog with 0 failures in 10.85 sec
Finished: plan profiles::nginx_install in 21.42 sec
Plan completed successfully with no result
```

In order to verify the deployment is operating as expected use the following `curl` commands to see the load balancer delegating to the different web servers.

```bash
curl http://0.0.0.0:20080/`
```

We expect the result to vary between based on the load balancer
```
hello! from localhost
```
and 
```
hello! from 127.0.0.1
```
**Note**: You can also navigate to `http://0.0.0.0:20080/` in a web browser. Just be aware that your browser will likely cache the result and therefore you may not see the oscillation between the two servers behind the load balancer. 

# Next steps

Now that you have learned about applying existing module content you can harness the power of the Puppet forge to manage infrastructure and deploy great applications!
