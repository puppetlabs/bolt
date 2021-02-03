# Installing Bolt

Packaged versions of Bolt are available for many modern Linux distributions, as
well as macOS and Windows.

> **What about Puppet?** You don't need to install Puppet to use Bolt. If you
> have Puppet installed on your machine, Bolt uses its internal version of
> Puppet and does not conflict with the Puppet version you have installed.

> **Note:** Bolt automatically collects data about how you use it. If you want
> to opt out of providing this data, you can do so. For more information, see
> [Analytics data collection](bolt_installing.md#analytics-data-collection)

Have questions? Get in touch. We're in #bolt on the [Puppet community
Slack](https://slack.puppet.com/).

## Installing Bolt on Windows

Use one of the supported Windows installation methods to install Bolt.

### Install Bolt with Windows Installer (MSI) 

Use the MSI installer package to install Bolt on Windows:
1.  Download the [Bolt installer
    package](https://downloads.puppet.com/windows/puppet-tools/puppet-bolt-x64-latest.msi).
1.  Double-click the MSI file and run the installer.
1.  Open PowerShell and run a Bolt command.
    ```
    bolt --help
    ```

If you see an error message instead of the expected output, you probably need to
follow one or both of the additional steps below. See [Add the Bolt module to
PowerShell](bolt_installing.md#add-the-bolt-module-to-powershell) and [Change
execution policy
restrictions](bolt_installing.md#change-execution-policy-restrictions).

#### Upgrading Bolt with the MSI

If you installed Bolt using the MSI, download the MSI again and repeat the
installation steps to install the latest version.

#### Uninstalling Bolt with the MSI

If you installed Bolt using the MSI, you can uninstall it from Windows **Apps &
Features**:
1. Press **Windows+X**, **F** to open **Apps & Features**.
2. Search for `Puppet Bolt`, select it, and click **Uninstall**.

### Install Bolt with Chocolatey

You must have the [Chocolatey package
manager](https://chocolatey.org/docs/installation) installed.

1.  Download and install the bolt package:
    ```
    choco install puppet-bolt
    ```
2.  Run a Bolt command and get started:
    ```
    bolt --help
    ```

If you see an error message instead of the expected output, you probably need to
follow one or both of the additional steps below. See [Add the Bolt module to
PowerShell](bolt_installing.md#add-the-bolt-module-to-powershell) and [Change
execution policy
restrictions](bolt_installing.md#change-execution-policy-restrictions).

#### Upgrading Bolt with Chocolatey

Use the following command to upgrade Bolt:
```
choco upgrade puppet-bolt
```

#### Uninstalling Bolt with Chocolatey
Use the following command to uninstall Bolt:
```
choco uninstall puppet-bolt
```

### Add the Bolt module to PowerShell

PowerShell versions 2.0 and 3.0 cannot automatically discover and load the Bolt
module, so you'll need to add it manually. Unless your system dates from 2013 or
earlier, this situation probably does not apply to you. To confirm your version
run `$PSVersionTable` in PowerShell.

To allow PowerShell to load Bolt, add the correct module to your PowerShell
profile.

1.  Update your PowerShell profile.
    ```
    'Import-Module -Name ${Env:ProgramFiles}\WindowsPowerShell\Modules\PuppetBolt' | Out-File -Append $PROFILE
    ```
1.  Load the module in your current PowerShell window.
    ```
    . $PROFILE
    ```

### Change execution policy restrictions

PowerShell's execution policy is a safety feature that controls the conditions
under which PowerShell loads configuration files and runs scripts. This feature
helps prevent the execution of malicious scripts. The default policy is
`Restricted` (allow no scripts to run) for Windows _clients_ and `RemoteSigned`
(allow signed scripts and non-signed scripts not from the internet) for Windows
_servers_. Some environments change this to `AllSigned`, which only allows
scripts to run as long as they are signed by a trusted publisher.

As of Bolt 2.21.0, we sign Bolt PowerShell module files with a Puppet code
signing certificate. If your PowerShell environment uses an `AllSigned`
execution policy and you add Puppet as a trusted publisher, the `bolt` command
works without any further input. If you're using the `AllSigned` policy and you
have not added Puppet as a trusted publisher, you can accept the publisher
without having to change your execution policy.

If your environment uses a `Restricted` policy, you must change your policy to
`RemoteSigned` or `AllSigned`. Check with your security team before you make any
policy changes.

If you see this or a similar error when trying to run Bolt, you probably need to
change your script execution policy restrictions:

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

To change your script execution policy:

1.  Press **Windows+X**, **A** to run PowerShell as an administrator.

1.  Set your script execution policy to at least `RemoteSigned`:
    ```
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
    ```
    For more information about PowerShell execution policies, see Microsoft's
    documentation about [execution
    policies](http://go.microsoft.com/fwlink/?LinkID=135170) and [how to set
    them](https://msdn.microsoft.com/en-us/powershell/reference/5.1/microsoft.powershell.security/set-executionpolicy).


## Installing Bolt on macOS

Use one of the supported macOS installation methods to install Bolt. Newer versions of Bolt after
2.0.0 support only macOS 10.14 and 10.15. If you're using an earlier version of the Mac operating
system, [download and install Bolt 2.0.0](https://downloads.puppet.com/mac/puppet-tools/).

### Install Bolt with Homebrew

You must have the command line tools for macOS and the [Homebrew package
manager](https://brew.sh/) installed.

Download and install the Bolt package:
    
```
brew install --cask puppet-bolt
```

#### Upgrading Bolt with Homebrew

To upgrade Bolt, use the following command:

```
brew upgrade --cask puppet-bolt
```

#### Uninstalling Bolt with Homebrew

To uninstall Bolt with homebrew, use the following command: 

```
brew uninstall --cask puppet-bolt
```

### Install Bolt with macOS installer 

Use the Apple Disk Image (DMG) to install Bolt on macOS.

1.  Download the Bolt installer package for your macOS version.

    > 🔩 **Tip** To find the macOS version number on your Mac, go to the Apple
    > () menu in the corner of your screen and choose **About This Mac**.

    - 10.14 (Mojave)
      [https://downloads.puppet.com/mac/puppet-tools/10.14/x86_64/puppet-bolt-latest.dmg](https://downloads.puppet.com/mac/puppet-tools/10.14/x86_64/puppet-bolt-latest.dmg)
    - 10.15 (Catalina)
      [https://downloads.puppet.com/mac/puppet-tools/10.15/x86_64/puppet-bolt-latest.dmg](https://downloads.puppet.com/mac/puppet-tools/10.15/x86_64/puppet-bolt-latest.dmg)
1.  Double-click the `puppet-bolt-latest.dmg` file to mount it and then
    double-click `puppet-bolt-[version]-installer.pkg` to run the installer.
1.  Open Terminal and run a Bolt command and get started.
    ```
    bolt --help
    ```
> **Note:** If you get a "Command not found error" when you try to run Bolt,
> make sure you've added the `opt/puppetlabs/bin` PATH to `~/.bashrc` or the
> relevant profile for the shell you're using.  

#### Upgrading Bolt with macOS installer

If you installed Bolt using the macOS installer, download the DMG again and
repeat the installation steps to install the latest version.

## Installing Bolt on *nix

Use one of the supported *nix installation methods to install Bolt.

> **CAUTION:** These instructions include enabling the Puppet Tools repository.
> While Bolt can also be installed from the Puppet 6 or 5 platform repositories,
> adding these repositories to a Puppet-managed target, especially a 
> Puppet server, might result in an unsupported version of a package like 
> `puppet-agent` being installed. This can cause downtime, especially on a 
> Puppet server.

### Install Bolt on Debian or Ubuntu

The Puppet Tools repository for the APT package management system is
[https://apt.puppet.com](https://apt.puppet.com). Packages are named using the
convention `puppet-tools-release-<VERSION CODE NAME>.deb`. For example, the
release package for Puppet Tools on Debian 9 “Stretch” is
`puppet-tools-release-stretch.deb`.

To install Bolt on Ubuntu or Debian:
1.  Download and install the software and its dependencies. Use the commands
    appropriate to your system:
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

    -   Ubuntu 20.04
        ```shell script
        wget https://apt.puppet.com/puppet-tools-release-focal.deb
        sudo dpkg -i puppet-tools-release-focal.deb
        sudo apt-get update 
        sudo apt-get install puppet-bolt
        ```

2.  Run a Bolt command and get started.
    ```
    bolt --help
    ```

#### Upgrading Bolt on Debian and Ubuntu

To upgrade Bolt on Debian and Ubuntu, use the following commands:

```shell script
sudo apt-get update
sudo apt install puppet-bolt
```

#### Uninstalling Bolt on Debian and Ubuntu

To uninstall Bolt on Debian and Ubuntu, use the following command: 

```shell script
sudo apt remove puppet-bolt
```

### Install Bolt on RHEL, SLES, or Fedora

Packaged versions of Bolt are available for Red Hat Enterprise Linux 6 and 7,
SUSE Linux Enterprise Server 12, and Fedora 28-32.

The Puppet Tools repository for the YUM package management system is
[http://yum.puppet.com/puppet-tools/](http://yum.puppet.com/puppet-tools/).
Packages are named using the convention `puppet-tools-release-<OS
ABBREVIATION>-<OS VERSION>.noarch.rpm`. For example, the release package for
Puppet Tools on Linux 7 is `puppet-tools-release-el-7.noarch.rpm`.

1.  Download and install the software and its dependencies. Use the commands
    appropriate to your system.
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
    -   Fedora 30
        ```shell script
        sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-fedora-30.noarch.rpm
        sudo dnf install puppet-bolt
        ```
    -   Fedora 31
        ```shell script
        sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-fedora-31.noarch.rpm
        sudo dnf install puppet-bolt
        ```
    -   Fedora 32
        ```shell script
        sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-fedora-32.noarch.rpm
        sudo dnf install puppet-bolt
        ```
1.  Run a Bolt command and get started.
    ```
    bolt --help
    ```

#### Upgrading Bolt on RHEL, SLES, or Fedora

To upgrade Bolt on RHEL, use the following command:

```shell script
sudo yum install puppet-bolt
```

To upgrade Bolt on SUSE Linux Enterprise Server 12, use the following command:

```shell script
sudo zypper update puppet-bolt
```

To upgrade Bolt on Fedora, use the following command:
```
sudo dnf upgrade puppet-bolt
```

#### Uninstalling Bolt on RHEL, SLES, or Fedora

To uninstall Bolt on RHEL use the following command:

```shell script
sudo yum remove puppet-bolt
```

To uninstall Bolt on SUSE Linux Enterprise Server 12, use the following command:

```shell script
sudo zypper remove puppet-bolt
```

To uninstall Bolt on Fedora use the following command:

```shell script
sudo dnf remove puppet-bolt
```

## Install gems in Bolt's Ruby environment

Bolt packages include their own copy of Ruby.

When you install gems for use with Bolt, use the `--user-install` command-line
option to avoid requiring privileged access for installation. This option also
enables sharing gem content with Puppet installations — such as when running
`apply` on `localhost` — that use the same Ruby version.

To install a gem for use with Bolt, use the command appropriate to your
operating system:
- On Windows with the default install location:
    ```
    "C:/Program Files/Puppet Labs/Bolt/bin/gem.bat" install --user-install <GEM>
    ```
- On other platforms:
    ```
    /opt/puppetlabs/bolt/bin/gem install --user-install <GEM>
    ```

## Install Bolt as a gem

To install Bolt reliably and with all dependencies, use one of the Bolt
installation packages instead of a gem. 

Starting with Bolt 0.20.0, gem installations no longer include core task
modules.

## Analytics data collection

Bolt collects data about how you use it. You can opt out of providing this data.

### What data does Bolt collect?

-   Version of Bolt
-   The Bolt command executed (for example, `bolt task run` or `bolt plan
    show`), excluding arguments
-   The functions called from a plan, excluding arguments
-   User locale
-   Operating system and version
-   Transports used (SSH, WinRM, PCP) and number of targets
-   The number of targets and groups defined in the Bolt inventory file
-   The number of targets targeted with a Bolt command
-   The output format selected (human-readable, JSON)
-   Whether the Bolt project directory was determined from the location of a
    `bolt-project.yaml` file or with the `--project` command-line option
-   The number of times Bolt tasks and plans are run (not including user-defined
    tasks or plans.)
-   The number of statements in a manifest block, and how many resources that
    produces for each target
-   The number of steps in a YAML plan
-   The return type (expression vs. value) of a YAML plan
-   Which bundled plugins Bolt is using (not including user-installed plugins)

This data is associated with a random, non-identifiable user UUID.

To see the data Bolt collects, add `--log-level trace` to a command.

### Why does Bolt collect data?

Bolt collects data to help us understand how it's being used and make decisions
about how to improve it.

### How can I opt out of Bolt data collection?

To disable the collection of analytics data add the following line to
`~/.puppetlabs/etc/bolt/analytics.yaml`:

```yaml
disabled: true
```
