# Installing Bolt

> **Difficulty**: Basic

> **Time**: Approximately 10 minutes

In this exercise you will install Bolt so you can get started with Puppet Tasks. Follow the instructions for your operating system.

- [Installing Bolt on Windows](#installing-bolt-on-windows)
- [Installing Bolt on macOS](#install-bolt-on-mac-os-x)
- [Installing Bolt on Debian or Ubuntu](#install-bolt-from-apt-repositories-on-debian-or-ubuntu)
- [Installing Bolt on RHEL or SLES](#install-bolt-from-yum-repositories-on-rhel-or-sles)
- [Installing Bolt as a gem](#install-bolt-as-a-gem)

# Prerequisites

This lesson covers everything you need to install Bolt on your machine. Just select the guide below for your operating system.

## Install Bolt on Windows

1.  Download the Bolt installer package from [https://downloads.puppet.com/windows/puppet5/bolt-x64-latest.msi.](https://downloads.puppet.com/windows/puppet5/bolt-x64-latest.msi)
2.  Double-click the MSI file and run the installation.
3.  Run a Bolt command to verify it has installed correctly.  

    ```
    bolt --help
    ```


## Install Bolt on Mac OS X

1.  Download the Bolt installer package for your macOS version. 

    **Tip:** To find the macOS version number on your Mac, go to the Apple \(\) menu in the corner of your screen and choose **About This Mac**.

    -   10.11 \(El Capitan\) [https://downloads.puppet.com/mac/puppet5/10.11/x86\_64/bolt-latest.dmg](https://downloads.puppet.com/mac/puppet5/10.11/x86_64/bolt-latest.dmg)
    -   10.12 \(Sierra\) [https://downloads.puppet.com/mac/puppet5/10.12/x86\_64/bolt-latest.dmg](https://downloads.puppet.com/mac/puppet5/10.12/x86_64/bolt-latest.dmg)
    -   10.13 \(High Sierra\) [https://downloads.puppet.com/mac/puppet5/10.13/x86\_64/bolt-latest.dmg](https://downloads.puppet.com/mac/puppet5/10.13/x86_64/bolt-latest.dmg)
2.  Double-click the `bolt-latest.dmg` file to mount it and then double-click the `bolt-[version]-installer.pkg` to run the installation.
3.  Run a Bolt command to verify it has installed correctly.  

    ```
    bolt --help
    ```


## Install Bolt from apt repositories on Debian or Ubuntu

Packaged versions of Bolt are available for Debian 8 and 9 and Ubuntu 14.04 and 16.04.

The Puppet repository for the APT package management system is [https://apt.puppet.com](https://apt.puppet.com). Packages are named using the convention `<PLATFORM_VERSION>-release-<VERSION CODE NAME>.deb`. For example, the release package for Puppet 5 Platform on  8 “Jessie” is `puppet5-release-jessie.deb`.

**Note:** These packages include the Puppet 5 Platform. To install only the Bolt package you can install the packages directly as well.

1.  Download and install the software and its dependencies. Use the commands appropriate to your system.
    -   Debian 8

        ```
        wget https://apt.puppet.com/puppet5-release-jessie.deb
        sudo dpkg -i puppet5-release-jessie.deb
        sudo apt-get update 
        sudo apt-get install bolt
        
        ```

    -   Debian 9

        ```
        wget https://apt.puppet.com/puppet5-release-stretch.deb
        sudo dpkg -i puppet5-release-stretch.deb
        sudo apt-get update 
        sudo apt-get install bolt
        ```

    -   Ubuntu 14.04

        ```
        wget https://apt.puppet.com/puppet5-release-trusty.deb
        sudo dpkg -i puppet5-release-trusty.deb
        sudo apt-get update 
        sudo apt-get install bolt
        ```

    -   Ubuntu 16.04

        ```
        wget https://apt.puppet.com/puppet5-release-xenial.deb
        sudo dpkg -i puppet5-release-xenial.deb
        sudo apt-get update 
        sudo apt-get install bolt
        ```

2.  Run a Bolt command to verify it has installed correctly. 

    ```
    bolt --help
    ```


## Install Bolt from yum repositories on RHEL or SLES

Packaged versions of Bolt are available for Red Hat Enterprise Linux 6 and 7, SUSE Linux Enterprise Server 12.

The Puppet repository for the YUM package management system is [http://yum.puppet.com/puppet5/](http://yum.puppet.com/puppet5/) Packages are named using the convention `<PLATFORM_NAME>-release-<OS ABBREVIATION>-<OS VERSION>.noarch.rpm`. For example, the release package for Puppet 5 Platform on Linux 7 is `puppet5-release-el-7.noarch.rpm`.

**Note:** These packages include the Puppet 5 Platform. To install only the Bolt package you can install the packages directly as well.

1.  Download and install the software and its dependencies. Use the commands appropriate to your system.
    -   Enterprise Linux 6

        ```
        sudo rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-el-6.noarch.rpm
        sudo yum install bolt				
        ```

    -   Enterprise Linux 7

        ```
        sudo rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-el-7.noarch.rpm
        sudo yum install bolt
        ```

    -   SUSE Linux Enterprise Server 12

        ```
        sudo rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-sles-12.noarch.rpm
        sudo yum install bolt
        ```

2.  Run a Bolt command  to verify it has installed correctly.  

    ```
    bolt --help
    ```


## Install Bolt as a gem

Install Ruby 2.3 or above and Bolt.

If Ruby is already included in your operating system, verify that it is version 2.3 or above. Run the command `ruby --version`.

1.  To install the dependencies required to install Bolt, run the command that corresponds to your operating system.
    -   For Fedora 27

        ```
        dnf install -y ruby rubygem-json rubygem-ffi rubygem-bigdecimal rubygem-io-console
        ```

    -   For Debian 9 or Ubuntu 16.04

        ```
        apt-get install -y ruby ruby-ffi
        ```

    -   For Mac OS X 10.13 \(High Sierra\)

        ```
        xcode-select --install
        
        ```

    -   For Windows, you can download Ruby from [https://rubyinstaller.org/](https://rubyinstaller.org/) or the Chocolatey Windows package manager. Run subsequent commands in a Windows PowerShell session.
2.  To install Bolt, run `gem install bolt`
3.  Run a Bolt command to verify it has installed correctly.  

    ```
    bolt --help
    ```




# Next steps

Now that you have Bolt installed you can move on to:

[Setting up test nodes](../02-acquiring-nodes)
