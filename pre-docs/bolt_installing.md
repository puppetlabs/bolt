
# Installing Bolt

Packaged versions of Bolt are available for many modern Linux distributions,
as well as macOS and Windows.

## Install Bolt on Windows

Download from https://downloads.puppet.com/windows/puppet5/bolt-x64-latest.msi and install.

## Install Bolt on Mac OS X

Go to  > About This Mac to determine which version you're running.

Download and install using the following links:
* __10.11 (El Capitan)__ - https://downloads.puppet.com/mac/puppet5/10.11/x86_64/bolt-latest.dmg
* __10.12 (Sierra)__ - https://downloads.puppet.com/mac/puppet5/10.12/x86_64/bolt-latest.dmg
* __10.13 (High Sierra)__ - https://downloads.puppet.com/mac/puppet5/10.13/x86_64/bolt-latest.dmg

## Install Bolt from apt repositories on Debian or Ubuntu

Packaged versions of Bolt are available for Debian 8 and 9 and
Ubuntu 14.04 and 16.04.

The Puppet repository for the APT package management system is
https://apt.puppet.com. Packages are named using the convention
<PLATFORM_VERSION>-release-<VERSION CODE NAME>.deb. For example, the release
package for Puppet 5 Platform on 8 “Jessie” is puppet5-release-jessie.deb.

> Note: These repositories include the Puppet 5 Platform. If you wish to install
> only the Bolt package you can install the packages directly as well.

- Debian 8
  ```
  wget https://apt.puppet.com/puppet5-release-jessie.deb
  sudo dpkg -i puppet5-release-jessie.deb
  sudo apt-get update
  sudo apt-get install bolt
  ```
- Debian 9
  ```
  wget https://apt.puppet.com/puppet5-release-stretch.deb
  sudo dpkg -i puppet5-release-stretch.deb
  sudo apt-get update
  sudo apt-get install bolt
  ```
- Ubuntu 14.04
  ```
  wget https://apt.puppet.com/puppet5-release-trusty.deb
  sudo dpkg -i puppet5-release-trusty.deb
  sudo apt-get update
  sudo apt-get install bolt
  ```
- Ubuntu 16.04
  ```
  wget https://apt.puppet.com/puppet5-release-xenial.deb
  sudo dpkg -i puppet5-release-xenial.deb
  sudo apt-get update
  sudo apt-get install bolt
  ```

Get started with `bolt --help`.

## Install Bolt from yum reposities on RHEL or SLES

Packaged versions of Bolt are available for Red Hat Enterprise
Linux 6 and 7, SUSE Linux Enterprise Server 12.

The Puppet repository for the YUM package management system is
http://yum.puppet.com/puppet5/ Packages are named using the convention
<PLATFORM_NAME>-release-<OS ABBREVIATION>-<OS VERSION>.noarch.rpm. For example,
the release package for Puppet 5 Platform on Linux 7 is
puppet5-release-el-7.noarch.rpm.

> Note: These repositories include the Puppet 5 Platform. If you wish to install
> only the Bolt package you can install the packages directly as well.

- Enterprise Linux 6
  ```
  sudo rpm -Uvh  https://yum.puppet.com/puppet5/puppet5-release-el-6.noarch.rpm
  sudo yum install bolt
  ```
- Enterprise Linux 7
  ```
  sudo rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-el-7.noarch.rpm
  sudo yum install bolt
  ```
- SUSE Linux Enterprise Server 12
  ```
  sudo rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-sles-12.noarch.rpm
  sudo zypper install bolt
  ```

Get started with `bolt --help`.

## Install Bolt as a gem

Install Ruby 2.3+ and Bolt. Note that only very modern operating systems include a
supported version of Ruby.

### Install Bolt dependencies

- For Fedora 27
  ```
  dnf install -y ruby rubygem-json rubygem-ffi rubygem-bigdecimal rubygem-io-console
  ```
- For Debian 9 or Ubuntu 16.04
  ```
  apt-get install -y ruby ruby-ffi
  ```
- For Mac OS X 10.13 (High Sierra)
  ```
  xcode-select --install
  ```
- For Windows, you can download Ruby from https://rubyinstaller.org/ or the Chocolatey
  Windows package manager. Run subsequent commands in a Windows PowerShell session.

### Install Bolt

Run `gem install bolt`. Then get started with `bolt --help`.
