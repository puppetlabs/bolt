# Running Bolt from a Docker image

Bolt is available on Docker Hub, as an image called `puppet-bolt`.

## Downloading the image

Docker Hub contains different versions of Bolt, with tags corresponding to Bolt system package and Rubygem versions. The newest version has a `latest` tag.

You can download the latest image with this command:
```
docker pull puppet/puppet-bolt
```

## Running Bolt from a Docker image

When running Bolt from a Docker image, Docker creates a container and executes the Bolt command within that container. Running Bolt in this way is simple:
```console
$ docker run puppet/puppet-bolt command run 'cat /etc/os-release' -t localhost
Started on localhost...
Finished on localhost:
  STDOUT:
    NAME="Ubuntu"
    VERSION="16.04.6 LTS (Xenial Xerus)"
    ID=ubuntu
    ID_LIKE=debian
    PRETTY_NAME="Ubuntu 16.04.6 LTS"
    VERSION_ID="16.04"
    HOME_URL="http://www.ubuntu.com/"
    SUPPORT_URL="http://help.ubuntu.com/"
    BUG_REPORT_URL="http://bugs.launchpad.net/ubuntu/"
    VERSION_CODENAME=xenial
    UBUNTU_CODENAME=xenial
Successful on 1 target: localhost
Ran on 1 target in 0.00 seconds
```

As you can see from the above example, the `localhost` target is the *container* environment, not the *host* environment.

Typically you would want to run Bolt not against the container environment, but against a different computer. To do this, you must pass information to the Bolt container about how to connect to the target computer. You might also want to pass the container some custom module content for Bolt to use. The next sections describe three different techniques for sharing this kind of information between the host and the Docker container.

## Pass inventory as an environment variable

If you only need to pass information on how to connect to targets, and not any custom module content, you can pass the inventory information by assigning it to an environment variable. This `inventory.yaml` file contains all the information needed for connecting to an example target:

```yaml
version: 2
targets:
  - name: pnz2rzpxfzp95hh.delivery.puppetlabs.net
    alias: docker-example
    config:
      transport: ssh
      ssh:
        user: root
        password: secret-password
        host-key-check: false
```

Here is an example of running the built-in `facts` task against the target listed in inventory. Note that the command passes the contents of the inventory file via an environment variable:

```console
$ docker run --env "BOLT_INVENTORY=$(cat Boltdir/inventory.yaml)" \
puppet/puppet-bolt task run facts -t docker-example
Started on pnz2rzpxfzp95hh.delivery.puppetlabs.net...
Finished on pnz2rzpxfzp95hh.delivery.puppetlabs.net:
  {
    "os": {
      "name": "CentOS",
      "release": {
        "full": "7.2",
        "major": "7",
        "minor": "2"
      },
      "family": "RedHat"
    }
  }
Successful on 1 target: pnz2rzpxfzp95hh.delivery.puppetlabs.net
Ran on 1 target in 0.55 seconds
```

## Mount the host's Bolt project directory

Another way of passing information is to make your Bolt project directory (Boltdir) available to the container. Here is the directory structure of a typical Boltdir:

```console
$ tree
.
└── Boltdir
     ├── bolt.yaml
     ├── inventory.yaml
     ├── keys
     │    └── id_rsa-acceptance
     └── site-modules
           └── docker_task
                 └── tasks
                       └── init.sh

5 directories, 4 files
```

Here is sample content from relevant files in the Boltdir above.

**`bolt.yaml`**

This is a basic Bolt configuration file.

```yaml
log:
  console:
    level: notice
```

**`inventory.yaml`**

This lists a target, and connection information for that target.

```yaml
version: 2
targets:
  - name: pnz2rzpxfzp95hh.delivery.puppetlabs.net
    alias: docker-example
    config:
      transport: ssh
      ssh:
        user: root
        private-key: /Boltdir/keys/id_rsa-acceptance
        host-key-check: false
```

**`init.sh`**

This is a shell task that prints the contents of the `message` parameter.

```shell script
#!/bin/bash
echo "Message: ${PT_message}"
```

This command executes the Bolt task above within a Docker container, using a shared Boltdir to pass information to the container:

```console
$ docker run --mount type=bind,source=/path/to/Boltdir,destination=/Boltdir \
puppet/puppet-bolt task run docker_task message=hi -t docker-example
Started on pnz2rzpxfzp95hh.delivery.puppetlabs.net...
Finished on pnz2rzpxfzp95hh.delivery.puppetlabs.net:
  Message: hi
  {
  }
Successful on 1 target: pnz2rzpxfzp95hh.delivery.puppetlabs.net
Ran on 1 target in 0.56 seconds
```

The `--mount` flag maps the Bolt project directory on the Docker host to `/Boltdir` in the container. The container is tagged as `puppet-bolt` and the rest of the command is all native to Bolt.

## Building on top of the `puppet-bolt` Docker image

You can also extend the `puppet-bolt` image and copy in data that will always be available for that image.

For example, create a file called `Dockerfile` in this location within your Boltdir:

```console
$ tree
    .
    └── Boltdir
          ├── bolt.yaml
          ├── Dockerfile
          ├── inventory.yaml
          ├── keys
          │    └── id_rsa-acceptance
          └── site-modules
                └── docker_task
                      └── tasks
                            └── init.sh
    
    5 directories, 5 files
```

Give the Dockerfile the following content:

```
FROM puppet/puppet-bolt
COPY . /Boltdir
```

Now you can build a Docker image with your custom module content and tag it `my-extended-puppet-bolt` with this command:

```console
$ docker build . -t my-extended-puppet-bolt
Sending build context to Docker daemon  10.75kB
Step 1/2 : FROM puppet-bolt
 ---> 5d8d2c1166fc
Step 2/2 : COPY . /Boltdir
 ---> 03162d29a1ee
Successfully built 03162d29a1ee
Successfully tagged my-extended-puppet-bolt:latest
```

You can run that container with the custom module content and connection information available inside the container:

```console
$ docker run my-extended-puppet-bolt task run docker_task message=hi -t docker-example
Started on pnz2rzpxfzp95hh.delivery.puppetlabs.net...
Finished on pnz2rzpxfzp95hh.delivery.puppetlabs.net:
  Message: hi
  {
  }
Successful on 1 target: pnz2rzpxfzp95hh.delivery.puppetlabs.net
Ran on 1 target in 0.56 seconds
```