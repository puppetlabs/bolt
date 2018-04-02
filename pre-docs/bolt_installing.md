
# Installing Bolt

Install Bolt and any dependencies for your operating system, such as Ruby, a
GNU Compiler Collection (GCC) compiler and the Bolt gem.

Packaged versions of Bolt are available for select Linux distributions and
versions: Debian 8 and 9, Enterprise Linux 6 and 7, SUSE Linux Enterprise
Server 12 and Ubuntu 14.04 and 16.04.


## Install Bolt on *nix

Install Bolt and its dependencies on *nix platforms.

1. To install dependencies required to install Bolt, run the command that
  corresponds to your operating system.

  -  For Fedora 25
     ```
     dnf install -y make gcc redhat-rpm-config ruby-devel rubygem-rdoc
     ```
  - For Debian 9 or Ubuntu 16.04
    ```
    apt-get install -y make gcc ruby-dev
    ```

2. To install Bolt,
    ```
    run gem install bolt
    ```
3. Run a Bolt command to verify it has installed correctly.
    ```
    bolt --help
    ```

## Install Bolt on Mac OS X
Install Bolt and its dependencies on Mac OS X systems.

1. If you do not already have them, install the command line tools for Mac OS X.
   ```
   xcode-select --install
   ```

2. To install Bolt, run `gem install bolt`
3. Run a Bolt command to verify it has installed correctly.
```
bolt --help
```


## Install Bolt on Windows

Install Bolt and its dependencies on Windows systems.

1. If you do not already have it, install Ruby.

  You can download Ruby from https://rubyinstaller.org/ or the Chocolatey Windows package manager.
2. Start a Windows PowerShell session and refresh your environment refreshenv.
3. To install Bolt, run `gem install bolt`
4. Run a Bolt command to verify it has installed correctly.
  ```
  bolt --help
  ```

## Install Bolt from apt repositories on Debian or Ubuntu

Packaged versions of Bolt are available for Debian 8 and 9 and
Ubuntu 14.04 and 16.04.

The Puppet repository for the APT package management system is
https://apt.puppet.com. Packages are named using the convention
<PLATFORM_VERSION>-release-<VERSION CODE NAME>.deb. For example, the release
package for Puppet 5 Platform on 8 “Jessie” is puppet5-release-jessie.deb.

> Note: These packages require you to download the Puppet 5 Platform and include
> puppet-agent as a dependency. If you use an earlier puppet agent you'll have
> to upgrade it. Download and install the software and its
> dependencies. Use the commands appropriate to your system.

1. -  Debian 8
      ```
      wget https://apt.puppet.com/puppet5-release-jessie.deb
      sudo dpkg -i puppet5-release-jessie.deb
      sudo apt-get update
      sudo apt-get install bolt
      ```
   -  Debian 9

      ```
      wget https://apt.puppet.com/puppet5-release-stretch.deb
      sudo dpkg -i puppet5-release-stretch.deb
      sudo apt-get update
      sudo apt-get install bolt
      ```
   -  Ubuntu 14.04

      ```
      wget https://apt.puppet.com/puppet5-release-trusty.deb
      sudo dpkg -i puppet5-release-trusty.deb
      sudo apt-get update
      sudo apt-get install bolt
      ```
   -  Ubuntu 16.04
      ```
      wget https://apt.puppet.com/puppet5-release-xenial.deb
      sudo dpkg -i puppet5-release-xenial.deb
      sudo apt-get update
      sudo apt-get install bolt
      ```
2. Run a Bolt command to verify it has installed correctly.
   ```
   bolt --help
   ```


## Install Bolt from yum reposities on RHEL or SLES

Packaged versions of Bolt are available for Red Hat Enterprise
Linux 6 and 7, SUSE Linux Enterprise Server 12.

The Puppet repository for the YUM package management system is
http://yum.puppet.com/puppet5/ Packages are named using the convention
<PLATFORM_NAME>-release-<OS ABBREVIATION>-<OS VERSION>.noarch.rpm. For example,
the release package for Puppet 5 Platform on Linux 7 is
puppet5-release-el-7.noarch.rpm.

> Note: These packages require you to download the Puppet 5 Platform and include
> puppet-agent as a dependency. If you use an earlier puppet agent you'll have
> to upgrade it.  Download and install the software and its
> dependencies. Use the commands appropriate to your system.

1. -  Enterprise Linux 6
      ```
      sudo rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-el-6.noarch.rpm
      sudo yum install bolt
      ```
   -  Enterprise Linux 7
      ```
      sudo rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-el-7.noarch.rpm
      sudo yum install bolt
      ```
   -  SUSE Linux Enterprise Server 12
      ```
      sudo rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-sles-12.noarch.rpm
      sudo yum install bolt
      ```
2. Run a Bolt command to verify it has installed correctly.
   ```
   bolt --help
   ```
