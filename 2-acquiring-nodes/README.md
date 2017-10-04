# Acquiring nodes for use with Bolt

> **Difficulty**: Basic

> **Time**: Approximately 5 minutes

In this exercise you will create nodes with which you can experiment with `bolt`. We have provided multiple options below as examples, feel free to pick one.

- [Existing nodes](#existing-nodes)
- [Using Vagrant](#using-vagrant)
- [Using Docker](#using-docker)

# Prerequisites

If you're using [Vagrant](https://www.vagrantup.com/) or [Docker](https://www.docker.com/) you will need those installed on your local machine. For Docker we recommend [Docker for Mac](https://www.docker.com/docker-mac) or [Docker for Windows](https://www.docker.com/docker-windows) for people on those platforms.

# Existing nodes

If you already have, or can easily launch, a few Linux or Windows nodes then you're all set. These nodes would need to be accessible via SSH or WinRM but that's it. If you can already access them via an SSH or WinRM client then `bolt` should be able to access them too.

# Using Vagrant

Save the following as `Vagrantfile`, or use the file accompanying this exercise.

```ruby
$nodes_count = 1

if ENV['NODES'].to_i > 0 && ENV['NODES']
  $nodes_count = ENV['NODES'].to_i
end

Vagrant.configure('2') do |config|
  config.vm.box = 'centos/7'
  config.ssh.forward_agent = true

  (1..$nodes_count).each do |i|
    config.vm.define "node#{i}" do |node|
      ip = "192.168.50.#{i+100}"
      node.vm.network "private_network", ip: ip
      ['vmware_fusion', 'vmware_workstation', 'virtualbox'].each do |provider|
        config.vm.provider provider do |_, override|
          override.ssh.host = ip
          override.ssh.port = 22
        end unless ENV['BOOT']
      end
    end
  end
end
```

This will by default launch one node. Run the following command. We are assuming you have some familiarity with Vagrant and have a suitable hypervisor configured.

```
BOOT=true vagrant up
```

If you would like to run more than one SSH server then you can set the `NODES` environment variable and run `vagrant up` again. With a Linux shell this is:

```
NODES=3 BOOT=true vagrant up
```

Note that the `BOOT` environment variable is only required when launching new nodes with `vagrant up` and should be left out when running other commands like `vagrant ssh` or `vagrant ssh-config`.

On Windows you can do the same thing with PowerShell:

```powershell
$env:NODES = 3
vagrant up
```

Finally you can generate the SSH configuration so `bolt` knows how to authenticate with the SSH daemon. The following command will output the required details. 

```
vagrant ssh-config
```

Note that if you've created more than one SSH server as above, this should be:

```
NODES=3 vagrant ssh-config
```

You can save that so it will be automatically picked up by SSH clients like so:

```
mkdir ~/.ssh
vagrant ssh-config >> ~/.ssh/config
``` 

or

```
NODES=3 vagrant ssh-config >> ~/.ssh/config
```

When passing nodes to `bolt` in the following exercises you will use something like `--nodes node1,node2`, up to the number of nodes you decided to launch.


# Using Docker

Using Docker we can quickly launch a number of ephemeral SSH servers. To make that even easier we'll use Docker Compose. Save the following as `docker-compose.yml` or use the file accompanying this lab.

```yaml
version: '3'
services:
  ssh:
    image: rastasheep/ubuntu-sshd
    ports:
      - 22
```

Run the following command to launch a single SSH server in the background.

```
docker-compose up -d
```

If you'd like to launch more SSH servers then use the `--scale` flag like so:

```
docker-compose up --scale ssh=3 -d
```

You can see the running containers using `ps`:

```
docker-compose ps
        Name                 Command        State           Ports
-------------------------------------------------------------------------
2acquiringnodes_ssh_1   /usr/sbin/sshd -D   Up      0.0.0.0:32768->22/tcp
2acquiringnodes_ssh_2   /usr/sbin/sshd -D   Up      0.0.0.0:32769->22/tcp
```

Note the `Ports` column. We are forwarding a local port to the SSH server running in the container. So you should be able to SSH to `127.0.0.1:32768` (in the example above). 

The image sets the username to `root` and the password to `root`. Test the connection out if you have a local SSH client like so, changing the port to one you get from running the `docker-compose ps` command above.

```
ssh root@127.0.0.1:32768
```

When passing nodes to `bolt` in the next section you will use `--nodes 127.0.0.1:32768,127.0.0.1:32769`, replacing the ports with those you see when you run the `docker-compose ps` command shown above. 
