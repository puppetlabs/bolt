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

TODO: Create Rakefile with defined rake tasks for the above.

## Setup

Prior to running the test commands, you must install the dependencies. This is
accomplished by running `bundle install` from within the `acceptance`
directory of your `bolt` git clone.

## Environment variables
The following environment variables are used in conjunction with the
beaker command:

SSH_USER  _required_
    :  Value to be used by the tests as the user for connecting to all
    hosts using the `ssh` role. This user must already be present on the
    system. Typically `root` is commonly used.

SSH_PASSWORD  _required_
    :  Value to be used by the tests as the passord for the `SSH_USER`
     for connecting to all hosts over SSH.

WINRM_USER  _required_
    :  Value to be used by the tests as the user for connecting to all
    hosts using the `winrm` role. This user must already be present on
    the system.  Typically `Administrator` is commonly used.

WINRM_PASSWORD  _required_
    :  Value to be used by the tests as the passord for the `WINRM_USER`
     for connecting to all hosts over WinRM.

## Running Tests on the vcloud

### Gem

1. Create Beaker hosts file.
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
1. Run test suite with beaker
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
