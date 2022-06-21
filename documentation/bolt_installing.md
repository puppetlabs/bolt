# Installing Bolt

> Bolt automatically collects data about how you use it. If you want to opt
> out of providing this data, you can do so. For more information, see
> [Opt out of data collection](analytics.md#opt-out-of-data-collection).

Packaged versions of Bolt are available for several Linux distributions, macOS,
and Microsoft Windows.

| Operating system          | Versions            |
| ------------------------- | ------------------- |
| Debian                    | 9, 10, 11           |
| Fedora                    | 34                  |
| macOS                     | 11, 12              |
| Microsoft Windows*        | 10 Enterprise       |
| Microsoft Windows Server* | 2012R2, 2019        |
| RHEL                      | 6, 7, 8, 9          |
| SLES                      | 12, 15              |
| Ubuntu                    | 18.04, 20.04        |

> **Note:** Windows packages are automatically tested on the versions listed
> above, but might be installable on other versions.

## Install Bolt on Debian

**Install Bolt**

To install Bolt, run the appropriate command for the version of Debian you
have installed:

- _Debian 9_

  ```shell
  wget https://apt.puppet.com/puppet-tools-release-stretch.deb
  sudo dpkg -i puppet-tools-release-stretch.deb
  sudo apt-get update
  sudo apt-get install puppet-bolt
  ```

- _Debian 10_

  ```shell
  wget https://apt.puppet.com/puppet-tools-release-buster.deb
  sudo dpkg -i puppet-tools-release-buster.deb
  sudo apt-get update
  sudo apt-get install puppet-bolt
  ```

- _Debian 11_

  ```shell
  wget https://apt.puppet.com/puppet-tools-release-bullseye.deb
  sudo dpkg -i puppet-tools-release-bullseye.deb
  sudo apt-get update
  sudo apt-get install puppet-bolt
  ```

**Upgrade Bolt**

To upgrade Bolt to the latest version, run the following command:

```shell
sudo apt-get update
sudo apt install puppet-bolt
```

**Uninstall Bolt**

To uninstall Bolt, run the following command:

```shell
sudo apt remove puppet-bolt
```

## Install Bolt on Fedora

**Install Bolt**

To install Bolt, run the appropriate command for the version of Fedora you
have installed:

- _Fedora 34_

  ```shell
  sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-fedora-34.noarch.rpm
  sudo dnf install puppet-bolt
  ```

**Upgrade Bolt**

To upgrade Bolt to the latest version, run the following command:

```shell
sudo dnf upgrade puppet-bolt
```

**Uninstall Bolt**

To uninstall Bolt, run the following command:

```shell
sudo dnf remove puppet-bolt
```

## Install Bolt on macOS

You can install Bolt packages for macOS using either Homebrew or the
macOS installer.

### Homebrew

**Install Bolt**

To install Bolt with Homebrew, you must have the [Homebrew package
manager](https://brew.sh/) installed.

1. Tap the Puppet formula repository:

   ```shell
   brew tap puppetlabs/puppet
   ```

1. Install Bolt:

   ```shell
   brew install --cask puppet-bolt
   ```

**Upgrade Bolt**

To upgrade Bolt to the latest version, run the following command:

```shell
brew upgrade --cask puppet-bolt
```

**Uninstall Bolt**

To uninstall Bolt, run the following command:

```shell
brew uninstall --cask puppet-bolt
```

### macOS installer (DMG)

**Install Bolt**

Use the Apple Disk Image (DMG) to install Bolt on macOS:

1. Download the Bolt installer package for your macOS version.

   - [11 (Big Sur)](https://downloads.puppet.com/mac/puppet-tools/11/x86_64/puppet-bolt-latest.dmg)
   - [12 (Monterey)](https://downloads.puppet.com/mac/puppet-tools/12/x86_64/puppet-bolt-latest.dmg)

1. Double-click the `puppet-bolt-latest.dmg` file to mount the installer and
   then double-click `puppet-bolt-[version]-installer.pkg` to run the installer.

If you get a message that the installer "can't be opened because Apple cannot check it for malicious software:"
1. Click **** > **System Preferences** > **Security & Privacy**.
1. From the **General** tab, click the lock icon to allow changes to your security settings and enter your macOS password.
1. Look for a message that says the Bolt installer "was blocked from use because it is not from an identified developer" and click "Open Anyway".
1. Click the lock icon again to lock your security settings.

**Upgrade Bolt**

To upgrade Bolt to the latest version, download the DMG again and repeat the
installation steps.

**Uninstall Bolt**

To uninstall Bolt, remove Bolt's files and executable:

```shell
sudo rm -rf /opt/puppetlabs/bolt /opt/puppetlabs/bin/bolt
```

## Install Bolt on Microsoft Windows

Use one of the supported Windows installation methods to install Bolt.

### Chocolatey

**Install Bolt**

To install Bolt with Chocolatey, you must have the [Chocolatey package
manager](https://chocolatey.org/docs/installation) installed.

1.  Download and install the bolt package:

    ```powershell
    choco install puppet-bolt
    ```

1.  Refresh the environment:

    ```powershell
    refreshenv
    ```

1. Install the [PuppetBolt PowerShell module](#puppetbolt-powershell-module).

1. Run a [Bolt cmdlet](bolt_cmdlet_reference.md). If you see an error message
   instead of the expected output, you might need to [add the Bolt module to
   PowerShell](troubleshooting.md#powershell-does-not-recognize-bolt-cmdlets) or
   [change execution policy
   restrictions](troubleshooting.md#powershell-could-not-load-the-bolt-powershell-module).

**Upgrade Bolt**

To upgrade Bolt to the latest version, run the following command:

```powershell
choco upgrade puppet-bolt
```

**Uninstall Bolt**

To uninstall Bolt, run the following command:

```powershell
choco uninstall puppet-bolt
```

### Windows installer (MSI)

**Install Bolt**

Use the Windows installer (MSI) package to install Bolt on Windows:

1.  Download the [Bolt installer
    package](https://downloads.puppet.com/windows/puppet-tools/puppet-bolt-x64-latest.msi).

1.  Double-click the MSI file and run the installer.

1. Install the [PuppetBolt PowerShell module](#puppetbolt-powershell-module).

1.  Open a new PowerShell window and run a [Bolt cmdlet](bolt_cmdlet_reference.md).
    If you see an error message instead of the expected output, you might need to
    [add the Bolt module to
    PowerShell](troubleshooting.md#powershell-does-not-recognize-bolt-cmdlets) or [change
    execution policy
    restrictions](troubleshooting.md#powershell-could-not-load-the-bolt-powershell-module).

**Upgrade Bolt**

To upgrade Bolt to the latest version, download the MSI again and repeat the
installation steps.

**Uninstall Bolt**

You can uninstall Bolt from Windows **Apps & Features**:

1. Press **Windows** + **X** + **F** to open **Apps & Features**.

1. Search for **Puppet Bolt**, select it, and click **Uninstall**.

### PuppetBolt PowerShell module

The PuppetBolt PowerShell module is available on the [PowerShell
Gallery](https://www.powershellgallery.com/packages/PuppetBolt) and includes
help documents and [PowerShell cmdlets](bolt_cmdlet_reference.md) for running
each of Bolt's commands. New versions of the PuppetBolt module are shipped at the
same time as a new Bolt release.

**Install PuppetBolt**

To install the PuppetBolt PowerShell module, run the following command in
PowerShell:

```powershell
Install-Module PuppetBolt
```

**Update PuppetBolt**

To update the PuppetBolt PowerShell module, run the following command in
PowerShell:

```powershell
Update-Module PuppetBolt
```

**Uninstall PuppetBolt**

To uninstall the PuppetBolt PowerShell module, run the following command in
PowerShell:

```powershell
Remove-Module PuppetBolt
```

## Install Bolt on RHEL

**Install Bolt**

To install Bolt, run the appropriate command for the version of RHEL you
have installed:

- _RHEL 6_

  ```shell
  sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-6.noarch.rpm
  sudo yum install puppet-bolt 
  ```

- _RHEL 7_

  ```shell
  sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-7.noarch.rpm
  sudo yum install puppet-bolt
  ```

- _RHEL 8_

  ```shell
  sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-8.noarch.rpm
  sudo yum install puppet-bolt
  ```

- _RHEL 9_

  ```shell
  sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-9.noarch.rpm
  sudo yum install puppet-bolt
  ```

**Upgrade Bolt**

To upgrade Bolt to the latest version, run the following command:

```shell
sudo yum update puppet-bolt
```

**Uninstall Bolt**

To uninstall Bolt, run the following command:

```shell
sudo yum remove puppet-bolt
```

## Install Bolt on SLES

**Install Bolt**

To install Bolt, run the appropriate command for the version of SLES you
have installed:

- _SLES 12_

  ```shell
  sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-sles-12.noarch.rpm
  sudo zypper install puppet-bolt
  ```

- _SLES 15_

  ```shell
  sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-sles-15.noarch.rpm
  sudo zypper install puppet-bolt
  ```

**Upgrade Bolt**

To upgrade Bolt to the latest version, run the following command:

```shell
sudo zypper update puppet-bolt
```

**Uninstall Bolt**

To uninstall Bolt, run the following command:

```shell
sudo zypper remove puppet-bolt
```

## Install Bolt on Ubuntu

**Install Bolt**

To install Bolt, run the appropriate command for the version of Ubuntu you
have installed:

- _Ubuntu 18.04_

  ```shell
  wget https://apt.puppet.com/puppet-tools-release-bionic.deb
  sudo dpkg -i puppet-tools-release-bionic.deb
  sudo apt-get update 
  sudo apt-get install puppet-bolt
  ```

- _Ubuntu 20.04_

  ```shell
  wget https://apt.puppet.com/puppet-tools-release-focal.deb
  sudo dpkg -i puppet-tools-release-focal.deb
  sudo apt-get update 
  sudo apt-get install puppet-bolt
  ```

**Upgrade Bolt**

To upgrade Bolt to the latest version, run the following command:

```shell
sudo apt-get update
sudo apt install puppet-bolt
```

**Uninstall Bolt**

To uninstall Bolt, run the following command:

```shell
sudo apt remove puppet-bolt
```

## Install Bolt as a gem

To install Bolt reliably and with all dependencies, use one of the Bolt
installation packages instead of a gem. Gem installations do not include core
modules which are required for common Bolt actions.

To install Bolt as a gem:

```shell
gem install bolt
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
