# Running Acceptance Tests

This acceptance suite allows you to test bolt using the following methods:

* gem: Install bolt via gem from a gemsource defined as an environment
  variable (defaults to https://gems.rubygems.org).
* git: Install bolt via the git repo from a branch/SHA defined as
  environment variables (defaults to #master/HEAD).

The tests assume the following Beaker roles be assigned to your SUT nodes:
* `bolt`: This role defines the node that will act as the `bolt`
  controller node. There should be only one `bolt` node defined in a
  given Beaker hosts file.
* `ssh`: Nodes defined with this role will be used to test bolt's SSH
  connection protocal. Any number of nodes can be defined with this role.
* `winrm`: Nodes defined with this role will be used to test bolt's WinRM
  connection protocal. Any number of nodes can be defined with this role.


## Setup

Prior to running the test commands, you must install the dependencies. This is
accomplished by running `bundle install` from within the `acceptance`
directory of your `bolt` git clone.

## Environment variables
The following environment variables are used in conjunction with the
rake tasks:

BOLT_CONTOLLER  _required_ (for rake task)
    :  Operating system and architecture to be used for the node running
    `bolt`. This value should be expressed in the notation used by
    `beaker-hostgenerator` (i.e.`windows10ent-64`).

BOLT_NODES  _required_ (for rake task)
    :  Operating system and architecture to be used for the nodes targeted by
    the bolt tests. This value should be expressed in the notation used by
    `beaker-hostgenerator`. Multiples should be comma separated
    (i.e.`ubuntu1604-64,osx1012-64`).

SSH_USER
    :  Value to be used by the tests as the user for connecting to all
    hosts using the `ssh` role. This user must already be present on the
    system. If this variable is not provided, it will default to `root`.

SSH_PASSWORD  _required_
    :  Value to be used by the tests as the passord for the `SSH_USER`
     for connecting to all hosts over SSH.

WINRM_USER
    :  Value to be used by the tests as the user for connecting to all
    hosts using the `winrm` role. This user must already be present on
    the system. If this variable is not provided, it will default to
    `Administrator`.

WINRM_PASSWORD  _required_
    :  Value to be used by the tests as the passord for the `WINRM_USER`
     for connecting to all hosts over WinRM.

GEM_VERSION
    :  When testing via gem install, this value will be used by the test
    pre-suites for the bolt gem version to install on the bolt node. If this
    variable is not provided, it will default to `> 0.1.0`.

GEM_SOURCE
    :  When testing via gem install, this value will be used by the test
    pre-suites for the gem source to be used to install `bolt` from. If this
    variable is not provided, it will default to `https://rubygems.org`.

GIT_SERVER
    :  When testing via git install, this value will be used by the test
    pre-suites in conjunction with `GIT_FORK` to determine where the git repo
    should be obtained from. If this variable is not provided, it will default
    to `https://github.com`.

GIT_FORK
    :  When testing via git install, this value will be used by the test
    pre-suites in conjunction with `GIT_SERVER` to determine where the git repo
    should be obtained from. If this variable is not provided, it will default
    to `puppetlabs/bolt.git`.

GIT_BRANCH
    :  When testing via git install, this value will be used by the test
    pre-suites to determine what branch should be checked out for testing.
    If this variable is not provided, it will default to `master`.

GIT_SHA
    :  When testing via git install, this value will be used by the test
    pre-suites to determine what git ref should be checked out for testing.
    This variable supercedes `GIT_BRANCH` if provided.

## Running Tests on the vcloud

### Rake tasks
####  Gem
Example to test latest available gem from https://rubygems.org
```
BOLT_CONTROLLER=centos7-64                  \
BOLT_NODES=ubuntu1604-64,windows10ent-64    \
SSH_PASSWORD='S3@ret3'                      \
WINRM_PASSWORD='S3@ret3'                    \
bundle exec rake ci:test:gem
```

Example to test specific gem version from https://rubygems.mymirror.example.org
```
GEM_VERSION=0.5.0                           \
GEM_SOURCE=https://rubygems.mymirror.example.org  \
BOLT_CONTROLLER=centos7-64                  \
BOLT_NODES=ubuntu1604-64,windows10ent-64    \
SSH_PASSWORD='S3@ret3'                      \
WINRM_PASSWORD='S3@ret3'                    \
bundle exec rake ci:test:gem
```

#### Git
Example to test latest git commit to master on https://github.com/puppetlabs/bolt
```
BOLT_CONTROLLER=centos7-64                  \
BOLT_NODES=ubuntu1604-64,windows10ent-64    \
SSH_PASSWORD='S3@ret3'                      \
WINRM_PASSWORD='S3@ret3'                    \
bundle exec rake ci:test:git
```

Example to test specific SHA on https://github.com/puppetlabs/bolt
```
GIT_SHA=309e197                             \
BOLT_CONTROLLER=centos7-64                  \
BOLT_NODES=ubuntu1604-64,windows10ent-64    \
SSH_PASSWORD='S3@ret3'                      \
WINRM_PASSWORD='S3@ret3'                    \
bundle exec rake ci:test:git
```

Example to test topic branch on fork of bolt on GitHub
```
GIT_FORK=octocat/bolt.git                   \
GIT_BRANCH=my-topic-branch                  \
BOLT_CONTROLLER=centos7-64                  \
BOLT_NODES=ubuntu1604-64,windows10ent-64    \
SSH_PASSWORD='S3@ret3'                      \
WINRM_PASSWORD='S3@ret3'                    \
bundle exec rake ci:test:git
```

### Beaker
The above rake tasks are the simplest method of executing the acceptance tests
for `bolt`. However, they assume that the default output of
`beaker-hostgenerator` will meet your needs. If this is not the case, you can
use `beaker-hostgenerator` to create the template for your beaker hosts file,
modify it to suite your infrastructure, and run beaker independently. This can
be helpful if you have existing hosts or do not want to use the `vmpooler`
hypervisor.

####  Hosts file

You should run `beaker-hostgenerator` to create the hosts.yaml file used by
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
file for the rake tasks. Since the rake tasks set the defaults for most of the
other environment variables, you will need to explicitly set them when running
beaker directly. The beaker options file will also need to be specified for
the type of bolt installation that should be performed (gem or git).

Example of running test suite using gem install using an existing hosts file:
```
SSH_USER=root                      \
SSH_PASSWORD='S3@ret3'             \
WINRM_USER=Administator            \
WINRM_PASSWORD='S3@ret3'           \
  bundle exec beaker               \
      -o config/gem/options.rb     \
      -h hosts.yaml                \
      -t tests
```
