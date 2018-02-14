# Installing Bolt

> **Difficulty**: Basic

> **Time**: Approximately 10 minutes

In this exercise you will install `bolt` so you can get started with Puppet Tasks. Just pick one of the following guides for your chosen operating system.

- [Installing Bolt on Windows](#installing-bolt-on-windows)
- [Installing Bolt on macOS](#installing-bolt-on-macos)
- [Installing Bolt on Linux](#installing-bolt-on-linux)

# Prerequisites

This lesson covers everything you need to install `bolt` on your own machine. Just select the guide below for your operating system.

# Installing Bolt on Windows

`bolt` is packaged as a Ruby gem, so you will need a Ruby environment installed on your machine. [Chocolatey](https://chocolatey.org/) is an excellent way to get Ruby installed and setup. If you don't have Chocolatey installed then you can follow the [Chocolatey installation instructions](https://chocolatey.org/install). With `choco` installed run the following in an Administrator PowerShell prompt.

```powershell
choco install ruby
refreshenv
gem install bolt
```

You can check everything has been installed correctly by running `bolt --help`.

# Installing Bolt on macOS

`bolt` is packaged as a Ruby gem, so you will need a Ruby environment installed. It also makes use of gems with native dependencies so you'll need a compiler toolchain. If you don't already have Xcode or similar installed you can do so with the following.

```
xcode-select --install
```

macOS comes with Ruby already installed so you should be able to install `bolt` using the built-in `gem` tool:

```
gem install bolt
```

You can check everything has been installed correctly by running `bolt --help`.


# Installing Bolt on Linux

`bolt` is packaged as a Ruby gem, so you will need a Ruby environment installed. It also makes use of gems with native dependencies so you'll need a compiler toolchain. The commands to install these dependencies vary based on which flavor of Linux you are running.

## CentOS 7/RHEL 7

```
yum install -y make gcc ruby-devel
gem install bolt
```

## Fedora 25

```
dnf install -y make gcc redhat-rpm-config ruby-devel rubygem-rdoc
gem install bolt
```

## Debian 9/Ubuntu 16.04

```
apt-get install -y make gcc ruby-dev
gem install bolt
```

# Next steps

Now that you have `bolt` installed you can move on to:

1. [Acquiring nodes](../2-acquiring-nodes)
