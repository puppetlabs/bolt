# Installing Bolt

Packaged versions of Bolt are available for many modern Linux distributions, as well as macOS and Windows.

**Tip:** Bolt uses an internal version of Puppet that supports tasks and plans, so you do not need to install Puppet. If you use Bolt on a machine that has Puppet installed, then Bolt uses its internal version of Puppet and does not conflict with the Puppet version you have installed.

**Note:** Bolt automatically collects data about how you use it. If you want to opt out of providing this data, you can do so. For more information see, [Analytics data collection](bolt_installing.md#)

## Install Bolt on Windows

Install Bolt on Windows systems via an MSI installer package.

1.   Download the Bolt installer package from [https://downloads.puppet.com/windows/puppet5/puppet-bolt-x64-latest.msi](https://downloads.puppet.com/windows/puppet5/puppet-bolt-x64-latest.msi). 
2.   Double-click the MSI file and run the installation. 
3.   Run a Bolt command and get started. 

    ```
    bolt --help
    ```


## Install Bolt with Chocolatey

Use the package manager Chocolatey to install Bolt on Windows.

You must have the Chocolatey package manager installed.

1.   Download and install the bolt package. 

    ```
    choco install puppet-bolt
    
    ```

2.   Run a Bolt command and get started. 

    ```
    bolt --help
    ```


## Install Bolt on Mac OS X

Install Bolt on Mac OS X systems.

1.   Download the Bolt installer package for your macOS version. 

    **Tip:** To find the macOS version number on your Mac, go to the Apple \(\) menu in the corner of your screen and choose **About This Mac**.

    -   10.11 \(El Capitan\) [https://downloads.puppet.com/mac/puppet5/10.11/x86\_64/puppet-bolt-latest.dmg](https://downloads.puppet.com/mac/puppet5/10.11/x86_64/puppet-bolt-latest.dmg)
    -   10.12 \(Sierra\) [https://downloads.puppet.com/mac/puppet5/10.12/x86\_64/puppet-bolt-latest.dmg](https://downloads.puppet.com/mac/puppet5/10.12/x86_64/puppet-bolt-latest.dmg)
    -   10.13 \(High Sierra\) [https://downloads.puppet.com/mac/puppet5/10.13/x86\_64/puppet-bolt-latest.dmg](https://downloads.puppet.com/mac/puppet5/10.13/x86_64/puppet-bolt-latest.dmg)
2.   Double-click the `puppet-bolt-latest.dmg` file to mount it and then double-click the `puppet-bolt-[version]-installer.pkg` to run the installation. 
3.   Run a Bolt command and get started. 

    ```
    bolt --help
    ```


## Install Bolt with Homebrew

Use the package manager Homebrew to install Bolt on Mac OS X.

You must have the command line tools for Mac OS X and the Homebrew package manager installed.

1.   Download and install the bolt package. 

    ```
    brew cask install puppetlabs/puppet/puppet-bolt
    
    ```

2.   Run a Bolt command and get started. 

    ```
    bolt --help
    ```


## Install Bolt from apt repositories on Debian or Ubuntu

Packaged versions of Bolt are available for Debian 8 and 9 and Ubuntu 14.04 and 16.04.

The Puppet repository for the APT package management system is [https://apt.puppet.com](https://apt.puppet.com). Packages are named using the convention `<PLATFORM_VERSION>-release-<VERSION CODE NAME>.deb`. For example, the release package for Puppet 5 Platform on Debian 8 “Jessie” is `puppet5-release-jessie.deb`.

**Note:** These packages require you to download the Puppet 5 Platform. To install only the Bolt package you can install the packages directly as well.

1.   Download and install the software and its dependencies. Use the commands appropriate to your system. 
    -    Debian 8

        ```
        wget https://apt.puppet.com/puppet5-release-jessie.deb
        sudo dpkg -i puppet5-release-jessie.deb
        sudo apt-get update 
        sudo apt-get install puppet-bolt
        
        ```

    -    Debian 9

        ```
        wget https://apt.puppet.com/puppet5-release-stretch.deb
        sudo dpkg -i puppet5-release-stretch.deb
        sudo apt-get update 
        sudo apt-get install puppet-bolt
        ```

    -    Ubuntu 14.04

        ```
        wget https://apt.puppet.com/puppet5-release-trusty.deb
        sudo dpkg -i puppet5-release-trusty.deb
        sudo apt-get update 
        sudo apt-get install puppet-bolt
        ```

    -    Ubuntu 16.04

        ```
        wget https://apt.puppet.com/puppet5-release-xenial.deb
        sudo dpkg -i puppet5-release-xenial.deb
        sudo apt-get update 
        sudo apt-get install puppet-bolt
        ```

2.   Run a Bolt command and get started. 

    ```
    bolt --help
    ```


## Install Bolt from yum repositories on RHEL or SLES

Packaged versions of Bolt are available for Red Hat Enterprise Linux 6 and 7, SUSE Linux Enterprise Server 12.

The Puppet repository for the YUM package management system is [http://yum.puppet.com/puppet5/](http://yum.puppet.com/puppet5/) Packages are named using the convention `<PLATFORM_NAME>-release-<OS ABBREVIATION>-<OS VERSION>.noarch.rpm`. For example, the release package for Puppet 5 Platform on Linux 7 is `puppet5-release-el-7.noarch.rpm`.

**Note:** These packages require you to download the Puppet 5 Platform. To install only the Bolt package you can install the packages directly as well.

1.   Download and install the software and its dependencies. Use the commands appropriate to your system. 
    -   Enterprise Linux 6

        ```
        sudo rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-el-6.noarch.rpm
        sudo yum install puppet-bolt				
        ```

    -   Enterprise Linux 7

        ```
        sudo rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-el-7.noarch.rpm
        sudo yum install puppet-bolt
        ```

    -   SUSE Linux Enterprise Server 12

        ```
        sudo rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-sles-12.noarch.rpm
        sudo zypper install puppet-bolt
        ```

2.   Run a Bolt command and get started. 

    ```
    bolt --help
    ```


## Install Bolt as a gem

Install Ruby 2.3 or above and Bolt.

If Ruby is already included in your operating system, verify that it is version 2.3 or above. Run `ruby -v`.

1.   To install the dependencies required to install Bolt, run the command that corresponds to your operating system. 
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
2.   To install Bolt, run `gem install bolt` 
3.   Run a Bolt command and get started. 

    ```
    bolt --help
    ```
4. Copy the contents of [bolt's Puppetfile](../Puppetfile) to `~/.puppetlabs/bolt/Puppetfile`:
```
forge "http://forge.puppetlabs.com"

moduledir File.join(File.dirname(__FILE__), 'modules')

mod 'puppetlabs-package', '0.2.0'
mod 'puppetlabs-service', '0.3.1'
mod 'puppetlabs-puppet_conf', '0.2.0'
mod 'puppetlabs-facts', '0.2.0'
mod 'puppet_agent',
    git: 'https://github.com/puppetlabs/puppetlabs-puppet_agent',
    ref: '319ce44a65e73bcf2712ad17be01f9636f0673c9'

# If we don't list these modules explicitly, r10k will purge them
mod 'canary', local: true
mod 'aggregate', local: true
mod 'puppetdb_fact', local: true
```
5. Run `bolt puppetfile install`

## Analytics data collection

Bolt collects data about how you use it. You can opt out of providing this data.

### What data does Bolt collect?

-   Version of Bolt
-   The Bolt command executed \(for example, `bolt task run` or `bolt plan show`\), excluding arguments
-   The functions called from a plan, excluding arguments

-   User locale
-   Operating system and version
-   Transports used \(SSH, WinRM, PCP\) and number of targets
-   The number of nodes and groups defined in the Bolt inventory file

-   The number of nodes targeted with a Bolt command

-   The output format selected \(human-readable, JSON\) 

-   The number of times Bolt tasks and plans are run \(This does not include user-defined tasks or plans.\)


This data is associated with a random, non-identifiable user UUID.

To see the data Bolt collects, add `--debug` to a command.

### Why does Bolt collect data?

Bolt collects data to help us understand how it's being used and make decisions about how to improve it.

### How can I opt-out of Bolt data collection?

To disable the collection of analytics data add the following line to `~/.puppetlabs/bolt/analytics.yaml`:

```
disabled: true
```

