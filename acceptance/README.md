# Running Acceptance Tests

### Table of Contents

* [Description](#description)
* [Setup](#setup)
* [Environment variables](#environment-variables)
   * [Required](#required)
   * [Optional](#optional)
   * [For Gem Testing](#for-gem-testing)
   * [For Git Testing](#for-git-testing)
   * [For Package Testing](#for-package-testing)
* [Running Tests](#running-tests-on-the-vcloud)
   * [Rake tasks](#rake-tasks)
      * [On Specified Targets](#on-specified-targets)
      * [With Specified Users](#with-specified-users)
      * [Gem](#gem)
      * [Git](#git)
      * [Package](#package)
   * [With Beaker](#beaker)
      * [Hosts file](#hosts-file)
      * [Run test suite with beaker](#run-test-suite-with-beaker)

## Description

This acceptance suite allows you to test bolt using the following methods:

* gem: Install bolt via gem from a gemsource defined as an environment
 variable (defaults to https://gems.rubygems.org).
* git: Install bolt via the git repo from a branch or SHA defined as
 environment variables (defaults to #main/HEAD).
* package: Install bolt via the puppet repos 

The tests assume the following [Beaker
roles](https://github.com/puppetlabs/beaker/blob/master/docs/concepts/roles_what_are_they.md) be assigned to your SUT nodes:
* `bolt`: This role defines the node that will act as the `bolt`
 controller node. There should be only one `bolt` node defined in a
 given Beaker hosts file.
* `ssh`: Nodes defined with this role will be used to test bolt's SSH
 connection protocol. Any number of nodes can be defined with this role.
* `winrm`: Nodes defined with this role will be used to test bolt's WinRM
 connection protocol. Any number of nodes can be defined with this role.

You may also need to specify nodes for
[beaker-hostgenerator](https://github.com/puppetlabs/beaker-hostgenerator) to
use to test bolt on. You can see all of the available
operatingsystem-architecture nodes by running
```
beaker-hostgenerator --list
```

## Setup

Prior to running the test commands, you must install the dependencies. This
is accomplished by running `bundle install` from within the `acceptance`
directory of your `bolt` git clone.

## Environment variables

The following environment variables are used in conjunction with the
rake tasks:

### Optional

**BEAKER_KEYFILE** (Default `~/.ssh/id_rsa-acceptance`): The path to
the file Beaker should use as the ssh key.

**SSH_PASSWORD** (Default `bolt_secret_password`): Value to be used by the tests
as the password for the `SSH_USER` for connecting to all hosts over SSH. Setup
will update passwords on targets to match this value after connecting via
`BEAKER_KEYFILE`.

**WINRM_PASSWORD** (Default `bolt_secret_password`): Value to be used by the
tests as the passord for the `WINRM_USER` for connecting to all hosts over WinRM.
Setup will update passwords on targets to match this value after connecting via
`BEAKER_KEYFILE`.

**BOLT_CONTOLLER** (Default `centos7-64bolt`): Operating system and
architecture to be used for the node running `bolt`. This value should be one
of the OS-architecture strings used by
[beaker-hostgenerator](https://github.com/puppetlabs/beaker-hostgenerator)
(i.e.`windows10ent-64`). See the [beaker-hostgenerator
usage](https://github.com/puppetlabs/beaker-hostgenerator#usage) for more
information about formatting, and see the [examples](#examples) below for
examples. 

**BOLT_NODES** (Default `ubuntu1604-64,osx1012-64,windows10ent-64`):
Operating system and architecture to be used for the nodes targeted by the
bolt tests. This value should be expressed in the notation used by
[beaker-hostgenerator](https://github.com/puppetlabs/beaker-hostgenerator#usage).
Multiples should be hyphen separated. See [examples](#examples) below for
examples.

**SSH_USER** (Default `root`): Value to be used by the tests as the
user for connecting to all hosts using the `ssh` role. This user must
already be present on the system. If this variable is not provided, it
will default to `root`.

**WINRM_USER** (Default `Administrator`): Value to be used by the
tests as the user for connecting to all hosts using the `winrm` role.
This user must already be present on the system.

### For Gem Testing

**GEM_VERSION** (Default `> 0.1.0`): When testing via gem install,
this value will be used by the test pre-suites for the bolt gem
version to install on the bolt node. 

**GEM_SOURCE** (Default `https://rubygems.org`): When testing via gem
install, this value will be used by the test pre-suites for the gem
source to be used to install `bolt` from.

### For Git Testing

**GIT_SERVER** (Default `https://github.com`): When testing via git
install, this value will be used by the test pre-suites in conjunction
with `GIT_FORK` to determine where the git repo should be obtained
from.

**GIT_FORK** (Default `puppetlabs/bolt.git`): When testing via git
install, this value will be used by the test pre-suites in conjunction
with `GIT_SERVER` to determine where the git repo should be obtained
from.

**GIT_BRANCH** (Default `main`): When testing via git install, this
value will be used by the test pre-suites to determine what branch
should be checked out for testing.

**GIT_SHA** (No default): When testing via git install, this value
will be used by the test pre-suites to determine what git ref should
be checked out for testing.  This variable supersedes `GIT_BRANCH` if
provided.

### For Package Testing

**SHA** (No default): When testing via package install, this value
will be used by the test pre-suites to determine what package version
should be installed for testing.

## Running Tests

### Rake tasks

#### On Specified Targets

Example to run the tests on an ubuntu 16.04 controller with a redhat
node
```
BOLT_CONTROLLER='ubuntu1604-64' \
BOLT_NODES='redhat7-64' \
SSH_PASSWORD='S3@ret3' \
WINRM_PASSWORD='S3@ret3' \
bundle exec rake test:gem
```

#### With Specified Users

Example to run with a different user:

```
SSH_USER='foo' \
SSH_PASSWORD='S3@ret3' \
WINRM_PASSWORD='S3@ret3' \
bundle exec rake test:gem
```

```
WINRM_USER='Foo' \
SSH_PASSWORD='S3@ret3' \
WINRM_PASSWORD='S3@ret3' \
bundle exec rake test:gem
```

#### Gem

Example to test latest available gem from https://rubygems.org with
default targets and users:
```
SSH_PASSWORD='S3@ret3' \
WINRM_PASSWORD='S3@ret3' \
bundle exec rake test:gem
```

Example to test specific gem version from https://rubygems.mymirror.example.org
```
GEM_VERSION=0.5.0 \
GEM_SOURCE=https://rubygems.mymirror.example.org \
SSH_PASSWORD='S3@ret3' \
WINRM_PASSWORD='S3@ret3' \
bundle exec rake test:gem
```

#### Git

Example to test latest git commit to main on https://github.com/puppetlabs/bolt
```
SSH_PASSWORD='S3@ret3' \
WINRM_PASSWORD='S3@ret3' \
bundle exec rake test:git
```

Example to test specific SHA on https://github.com/puppetlabs/bolt
```
GIT_SHA=309e197  \
SSH_PASSWORD='S3@ret3' \
WINRM_PASSWORD='S3@ret3' \
bundle exec rake test:git
```

Example to test topic branch on fork of bolt on GitHub
```
GIT_FORK=octocat/bolt.git          \
GIT_BRANCH=my-topic-branch         \
SSH_PASSWORD='S3@ret3'           \
WINRM_PASSWORD='S3@ret3'          \
bundle exec rake test:git
```

#### Package
Example to test a specific package version from Puppet's internal package repos
```
SHA=261d55b5cc1e8a6d00f4ff4573e17048bea08c10 \
SSH_PASSWORD='S3@ret3' \
WINRM_PASSWORD='S3@ret3' \
bundle exec rake test:package
```

### Beaker

The above rake tasks are the simplest method of executing the acceptance
tests for `bolt`. However, they assume that the default output of
`beaker-hostgenerator` will meet your needs. If this is not the case, you can
use `beaker-hostgenerator` to create the template for your beaker hosts file,
modify it to suite your infrastructure, and run beaker independently. This
can be helpful if you have existing hosts or do not want to use the
`vmpooler` hypervisor.

#### Hosts file

You should run `beaker-hostgenerator` to create the `hosts.yaml` file used by
beaker to run the tests. The examples below illustrate common platforms to
test against.
_Centos 7_
The following example generates a host file with a Centos 7 bolt controller
with other operating systems used as external nodes to be acted upon by
`bolt`.
```
 bundle exec beaker-hostgenerator centos7-64bolt,ssh.-ubuntu1604-64ssh.-osx1012-64ssh.-windows10ent-64winrm. > hosts.yaml
```
_Ubuntu 16.04_
The following example generates a host file with a Ubuntu 16.04 bolt controller
with other operating systems used as external nodes to be acted upon by
`bolt`.
```
 bundle exec beaker-hostgenerator ubuntu1604-64bolt,ssh.-centos7-64ssh.-osx1012-64ssh.-windows10ent-64winrm. > hosts.yaml
```
_Windows 10 Enterprise_
The following example generates a host file with a Windows 10 bolt controller
with other operating systems used as external nodes to be acted upon by
`bolt`.
```
 bundle exec beaker-hostgenerator windows10ent-64bolt,winrm.-centos7-64ssh.-ubuntu1604-64ssh.-osx1012-64ssh. > hosts.yaml
```
_OS X 10.12_
The following example generates a host file with a OS X bolt controller
with other operating systems used as external nodes to be acted upon by
`bolt`.
```
 bundle exec beaker-hostgenerator osx1012-64bolt,ssh.-centos7-64ssh.-ubuntu1604-64ssh.-windows10ent-64winrm. > hosts.yaml
```

#### Run test suite with beaker

The `BOLT_CONTROLLER` and `BOLT_NODES` values are not needed when running
beaker directly. They are used by `beaker-hostgenerator` to create the hosts
file for the rake tasks. Since the rake tasks set the defaults for most of
the other environment variables, you will need to explicitly set them when
running beaker directly. The beaker options file will also need to be
specified for the type of bolt installation that should be performed (gem or
git).

Example of running test suite using gem install using an existing hosts file:
1. Initialize beaker with supplied options file for gem configuration.
    ```
    bundle exec beaker init -h hosts.yaml -o config/gem/options.rb
    ```
1. Provision hosts
    ```
    bundle exec beaker provision
    ```
1. Run pre-suite and tests with specified environment variables
    ```
    SSH_USER=root           \
    SSH_PASSWORD='S3@ret3'       \
    WINRM_USER=Administator      \
    WINRM_PASSWORD='S3@ret3'      \
    bundle exec beaker exec -t ./tests
    ```
1. Re-run tests
    ```
    bundle exec beaker exec ./tests
    ```
