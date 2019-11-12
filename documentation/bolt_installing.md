# Installing Bolt

Packaged versions of Bolt are available for many modern Linux distributions, as well as macOS and Windows.

Have questions? Get in touch. We're in #bolt on the [Puppet community Slack](https://slack.puppet.com/).

**Tip:** Bolt uses an internal version of Puppet that supports tasks and plans, so you do not need to install Puppet. If you use Bolt on a machine that has Puppet installed, Bolt uses its internal version of Puppet and does not conflict with the Puppet version you have installed.

**Note:** Bolt automatically collects data about how you use it. If you want to opt out of providing this data, you can do so. For more information see, [Analytics data collection](bolt_installing.md#)

## Install Bolt on Windows

Use one of the supported Windows installation methods to install Bolt.

### Install Bolt with MSI 

Use the MSI installer package to install Bolt on Windows.

1.  Download the [Bolt installer package](https://downloads.puppet.com/windows/puppet6/puppet-bolt-x64-latest.msi).
1.  Double-click the MSI file and run the installer.
1.  Run a Bolt command and get started.
    ```
    bolt --help
    ```

If you see an error message instead of the expected output, you probably need to follow one or both of the additional steps below. See [Add the Bolt module to PowerShell](bolt_installing.md#) and [Change execution policy restrictions](bolt_installing.md#).

### Install Bolt with Chocolatey

Use the package manager Chocolatey to install Bolt on Windows.

You must have the Chocolatey package manager installed.

1.  Download and install the bolt package.
    ```
    choco install puppet-bolt
    ```
1.  Run a Bolt command and get started.
    ```
    bolt --help
    ```

If you see an error message instead of the expected output, you probably need to follow one or both of the additional steps below. See [Add the Bolt module to PowerShell](bolt_installing.md#) and [Change execution policy restrictions](bolt_installing.md#).

### Add the Bolt module to PowerShell

PowerShell versions 2.0 and 3.0 cannot automatically discover and load the Bolt module, so you'll need to add it manually. Unless your system dates from 2013 or earlier, this situation probably does not apply to you. To confirm your version, run `echo $PSTableVersion` in PowerShell.

To allow PowerShell to load Bolt, add the correct module to your PowerShell profile.

1.  Update your PowerShell profile.
    ```
    'Import-Module -Name ${Env:ProgramFiles}\WindowsPowerShell\Modules\PuppetBolt' | Out-File -Append $PROFILE
    ```
1.  Load the module in your current PowerShell window.
    ```
    . $PROFILE
    ```

### Change execution policy restrictions

Some Windows installations have security restrictions that do not allow Bolt to run. These restrictions are easy to change, but check with your security team first.

If you see this or a similar error when trying to run Bolt, you probably need to change your script execution policy restrictions, as described here.

```
bolt : The 'bolt' command was found in the module 'PuppetBolt', but the module could not be loaded. 
For more information, run 'Import-Module PuppetBolt'.
                At line:1 char:1
                + bolt --help
                + ~~~~
                + CategoryInfo          : ObjectNotFound: (bolt:String) [], CommandNotFoundExceptio
                n
                + FullyQualifiedErrorId : CouldNotAutoloadMatchingModule
```
1.  Run PowerShell as an administrator:
    ```
    Windows-X, a
    ```
1.  Set your script execution policy to at least `RemoteSigned`:
    ```
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
    ```
    For more information about PowerShell execution policies, see Microsoft's documentation about [execution policies](http://go.microsoft.com/fwlink/?LinkID=135170) and [how to set them](https://msdn.microsoft.com/en-us/powershell/reference/5.1/microsoft.powershell.security/set-executionpolicy).


## Install Bolt on macOS

Use one of the supported macOS installation methods to install Bolt.

### Install Bolt with macOS installer 

Use the Apple Disk Image (DMG) to install Bolt on macOS.

1.  Download the Bolt installer package for your macOS version.
    
    **Tip:** To find the macOS version number on your Mac, go to the Apple () menu in the corner of your screen and choose **About This Mac**.
    - 10.11 (El Capitan) [https://downloads.puppet.com/mac/puppet6/10.11/x86_64/puppet-bolt-latest.dmg](https://downloads.puppet.com/mac/puppet6/10.11/x86_64/puppet-bolt-latest.dmg)
    - 10.12 (Sierra) [https://downloads.puppet.com/mac/puppet6/10.12/x86_64/puppet-bolt-latest.dmg](https://downloads.puppet.com/mac/puppet6/10.12/x86_64/puppet-bolt-latest.dmg)
    - 10.13 (High Sierra) [https://downloads.puppet.com/mac/puppet6/10.13/x86_64/puppet-bolt-latest.dmg](https://downloads.puppet.com/mac/puppet6/10.13/x86_64/puppet-bolt-latest.dmg)
    - 10.14 (Mojave) [https://downloads.puppet.com/mac/puppet6/10.14/x86_64/puppet-bolt-latest.dmg](https://downloads.puppet.com/mac/puppet6/10.14/x86_64/puppet-bolt-latest.dmg)
1.  Double-click the `puppet-bolt-latest.dmg` file to mount it and then double-click `puppet-bolt-[version]-installer.pkg` to run the installer.
1.  Run a Bolt command and get started.
    ```
    bolt --help
    ```

### Install Bolt with Homebrew

Use the package manager Homebrew to install Bolt on macOS.

You must have the command line tools for macOS and the Homebrew package manager installed.

1.  Download and install the Bolt package.
    ```
    brew cask install puppetlabs/puppet/puppet-bolt
    ```
2.  Run a Bolt command and get started.
    ```
    bolt --help
    ```

## Install Bolt on *nix

Use one of the supported *nix installation methods to install Bolt.

**CAUTION:** These instructions include enabling the Puppet Tools repository. While Bolt can also be installed from the Puppet 6 or 5 platform repositories, adding these repositories to a Puppet-managed target, especially a PE master, might result in an unsupported version of a package like `puppet-agent` being installed. This can cause downtime, especially on a PE master.

### Install Bolt on Debian or Ubuntu

Packaged versions of Bolt are available for Debian 8-10 and Ubuntu 16.04 and 18.04.

The Puppet Tools repository for the APT package management system is [https://apt.puppet.com](https://apt.puppet.com). Packages are named using the convention `puppet-tools-release-<VERSION CODE NAME>.deb`. For example, the release package for Puppet Tools on Debian 8 “Jessie” is `puppet-tools-release-jessie.deb`.

1.  Download and install the software and its dependencies. Use the commands appropriate to your system.
    -   Debian 8
        ```shell script
        wget https://apt.puppet.com/puppet-tools-release-jessie.deb
        sudo dpkg -i puppet-tools-release-jessie.deb
        sudo apt-get update 
        sudo apt-get install puppet-bolt
        ```
    -   Debian 9
        ```shell script
        wget https://apt.puppet.com/puppet-tools-release-stretch.deb
        sudo dpkg -i puppet-tools-release-stretch.deb
        sudo apt-get update 
        sudo apt-get install puppet-bolt
        ```
    -   Debian 10
        ```shell script
        wget https://apt.puppet.com/puppet-tools-release-buster.deb
        sudo dpkg -i puppet-tools-release-buster.deb
        sudo apt-get update 
        sudo apt-get install puppet-bolt
        ```
    -   Ubuntu 16.04
        ```shell script
        wget https://apt.puppet.com/puppet-tools-release-xenial.deb
        sudo dpkg -i puppet-tools-release-xenial.deb
        sudo apt-get update 
        sudo apt-get install puppet-bolt
        ```
    -   Ubuntu 18.04
        ```shell script
        wget https://apt.puppet.com/puppet-tools-release-bionic.deb
        sudo dpkg -i puppet-tools-release-bionic.deb
        sudo apt-get update 
        sudo apt-get install puppet-bolt
        ```

1.  Run a Bolt command and get started.
    ```
    bolt --help
    ```

### Install Bolt on RHEL, SLES, or Fedora

Packaged versions of Bolt are available for Red Hat Enterprise Linux 6 and 7, SUSE Linux Enterprise Server 12, and Fedora 28-30.

The Puppet Tools repository for the YUM package management system is [http://yum.puppet.com/puppet-tools/](http://yum.puppet.com/puppet-tools/). Packages are named using the convention `puppet-tools-release-<OS ABBREVIATION>-<OS VERSION>.noarch.rpm`. For example, the release package for Puppet Tools on Linux 7 is `puppet-tools-release-el-7.noarch.rpm`.

1.  Download and install the software and its dependencies. Use the commands appropriate to your system.
    -   RHEL 6
        ```shell script
        sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-6.noarch.rpm
        sudo yum install puppet-bolt			
        ```
    -   RHEL 7
        ```shell script
        sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-7.noarch.rpm
        sudo yum install puppet-bolt
        ```
    -   RHEL 8
        ```shell script
        sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-8.noarch.rpm
        sudo yum install puppet-bolt
        ```
    -   SUSE Linux Enterprise Server 12
        ```shell script
        sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-sles-12.noarch.rpm
        sudo zypper install puppet-bolt
        ```
    -   Fedora 28
        ```shell script
        sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-fedora-28.noarch.rpm
        sudo dnf install puppet-bolt
        ```
    -   Fedora 29
        ```shell script
        sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-fedora-29.noarch.rpm
        sudo dnf install puppet-bolt
        ```
    -   Fedora 30
        ```shell script
        sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-fedora-30.noarch.rpm
        sudo dnf install puppet-bolt
        ```
1.  Run a Bolt command and get started.
    ```
    bolt --help
    ```

## Install gems with Bolt packages

Bolt packages include their own copy of Ruby.

When you install gems for use with Bolt, use the `--user-install` flag to avoid requiring privileged access for installation. This option also enables sharing gem content with Puppet installations — such as when running `apply` on `localhost` — that use the same Ruby version.

To install a gem for use with Bolt, use the command appropriate to your operating system:
- On Windows with the default install location:
    ```
    "C:/Program Files/Puppet Labs/Bolt/bin/gem.bat" install --user-install <GEM>
    ```
- On other platforms:
    ```
    /opt/puppetlabs/bolt/bin/gem install --user-install <GEM>
    ```

## Install Bolt as a gem

Starting with Bolt 0.20.0, gem installations no longer include core task modules.

To install Bolt reliably and with all dependencies, use one of the Bolt installation packages instead of a gem.

## Running Bolt from a Docker image

Bolt is available on Docker Hub, as an image called `puppet-bolt`. There are a number of ways to run Bolt from a Docker image.

### Downloading the image

Docker Hub contains different versions of Bolt, with tags corresponding to Bolt system package and Rubygem versions. The newest version has a `latest` tag.

You can download the latest image with this command:
```
docker pull puppet/puppet-bolt
```

### Running Bolt from a Docker image

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

### Pass inventory as an environment variable

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

### Mount the host's Bolt project directory

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

### Building on top of the `puppet-bolt` Docker image

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

## Analytics data collection

Bolt collects data about how you use it. You can opt out of providing this data.

### What data does Bolt collect?

-   Version of Bolt
-   The Bolt command executed (for example, `bolt task run` or `bolt plan show`), excluding arguments
-   The functions called from a plan, excluding arguments
-   User locale
-   Operating system and version
-   Transports used (SSH, WinRM, PCP) and number of targets
-   The number of targets and groups defined in the Bolt inventory file
-   The number of targets targeted with a Bolt command
-   The output format selected (human-readable, JSON)
-   Whether the Bolt project directory was determined from the location of a `bolt.yaml` file or with the `--boltdir` flag
-   The number of times Bolt tasks and plans are run (not including user-defined tasks or plans.)
-   The number of statements in a manifest block, and how many resources that produces for each target
-   The number of steps in a YAML plan
-   The return type (expression vs. value) of a YAML plan
-   Which bundled plugins Bolt is using (not including user-installed plugins)

This data is associated with a random, non-identifiable user UUID.

To see the data Bolt collects, add `--debug` to a command.

### Why does Bolt collect data?

Bolt collects data to help us understand how it's being used and make decisions about how to improve it.

### How can I opt out of Bolt data collection?

To disable the collection of analytics data add the following line to `~/.puppetlabs/bolt/analytics.yaml`:
```yaml
disabled: true
```
