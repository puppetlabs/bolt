---
title: Setting up test nodes to use with Bolt
difficulty: Basic
time: Approximately 5 minutes
---

In this exercise you will create nodes that you can use to experiment with Bolt. You can also use existing nodes in your system if you prefer.

- [Existing nodes](#existing-nodes)
- [Using Vagrant](#using-vagrant)
- [Using Docker](#using-docker)

# Prerequisites
To use an attached configuration file to set up test nodes, you must have one of the following installed on your machine:

- [Vagrant](https://www.vagrantup.com/)
- [Docker for Mac](https://docs.docker.com/docker-for-mac/install/)
- [Docker for Windows](https://docs.docker.com/docker-for-windows/install/)

# Existing nodes

If you already have, or can easily launch, a few Linux or Windows nodes then you're all set. These nodes must be accessible via SSH or WinRM; if you can  access them via an SSH or WinRM client then Bolt can, too.

# Using Vagrant
**Note:** These instructions assume that you are familiar with Vagrant and have a suitable hypervisor configured.

The attached Vagrantfile configures three CentOS 7 nodes and a Windows (Nano Server) node.

Save the following code as `Vagrantfile` or [download the `Vagrantfile`](Vagrantfile) attached to this exercise. To configure a different number of nodes, change the `NODES` environment variable.

```ruby
{% include_relative Vagrantfile %}
```

From the command line, ensure you’re in the directory where you stored the Vagrantfile file and enter `vagrant up`.

Generate the SSH configuration so Bolt knows how to authenticate with the SSH daemon. The following command will output the required details.

```
vagrant ssh-config
```

You can save that so it will be automatically picked up by most SSH clients, including Bolt. This uses the ability to specify hosts along with their connection details in a [configuration file](https://linux.die.net/man/5/ssh_config).

```
mkdir ~/.ssh
vagrant ssh-config | sed /StrictHostKeyChecking/d | sed /UserKnownHostsFile/d >> ~/.ssh/config
```

By saving this SSH configuration file, you can use the node name, rather than the IP address. When passing nodes to Bolt in the following exercises with Linux you will use `--nodes node1,node2`.

Make sure you can SSH into all of your nodes. If you've used the vagrant nodes before you may have to remove entries from `~/.ssh/known_hosts`.

```
ssh node1
ssh node2
ssh node3
```

# Using Docker
Using Docker we can quickly launch a number of ephemeral SSH servers. To make that even easier we'll use Docker Compose.

Save the following code as `docker-compose.yml` or download the `docker-compose.yml` file attached to this exercise.

```yaml
{% include_relative docker-compose.yml %}
```

Save the following code as `Dockerfile` or download the `Dockerfile` attached to this exercise.

```docker
{% include_relative Dockerfile %}
```

Launch a single SSH server in the background: `docker-compose up -d`. To launch more SSH servers, run:  `docker-compose up --scale ssh=3 -d`.

View a list of running containers: `docker-compose ps`. The result should be similar to:

```
        Name                 Command        State           Ports
-------------------------------------------------------------------------
2acquiringnodes_ssh_1   /usr/sbin/sshd -D   Up      0.0.0.0:32768->22/tcp
2acquiringnodes_ssh_2   /usr/sbin/sshd -D   Up      0.0.0.0:32769->22/tcp
```

Note the `Ports` column. We are forwarding a local port to the SSH server running in the container. Using the example above, you can SSH to `127.0.0.1:32768`.

If you have a local SSH client, test the connection. Change the port to one you get from running the `docker-compose ps` command. The image sets the username and password to `root`.

```
ssh root@127.0.0.1 -p 32768
```

Make sure you can log into all the nodes before moving on. You may have to remove some entries from `~/.ssh/known_hosts`

When passing nodes to Bolt in the next section you will use `--nodes 127.0.0.1:32768,127.0.0.1:32769`, replacing the ports with those you see when you run the `docker-compose ps` command.

# Next steps

Now that you have set up test nodes to use with Bolt you can move on to:

[Running Commands](../03-running-commands)
