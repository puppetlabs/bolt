# Bolt + Kerberos

### Overview

Bolt supports using Kerberos as an authentication mechanism, in lieu of a username / password. An excellent background on key Kerberos concepts is available in [Designing an Authentication System: a Dialogue in Four Scenes](https://web.mit.edu/kerberos/www/dialogue.html).

While Linux **does** support a standalone Kerberos KDC (Key Distribution Center), the [`winrm`](https://github.com/WinRb/WinRM) gem that provides connectivity support from Bolt has only been written for and tested against Active Directory.

In the future, it's possible other transports like SSH might be able to authenticate and authorize with just a KDC, but for now, the primary use case for Kerberos is in conjunction with WinRM.

### Kerberos Implementations

There are three primary implementations of the Kerberos protocol widely available:

* [Heimdal](#heimdal)
* [MIT Kerberos](#mit-kerberos)
* [Microsoft Kerberos](#microsoft-kerberos)

#### Heimdal

[Heimdal](https://www.h5l.org/) is an open source implementation that is shipped on Mac OSX and is the default library used for the Samba server packages on Linux.

Even though Heimdal provided interoperability with [Microsoft DCE/RPC](https://en.wikipedia.org/wiki/DCE/RPC) first with the addition of [IOV message wrapping extension functions](https://web.mit.edu/kerberos/krb5-latest/doc/appdev/gssapi.html#iov-message-wrapping), these APIs are not exported in the OSX libraries that ship with the operating system.

The [gssapi](https://github.com/zenchild/gssapi) gem that Bolt relies on for [Generic Security Services](https://en.wikipedia.org/wiki/Generic_Security_Services_Application_Program_Interface) defaults to MIT Kerberos, but also supports Heimdal via a programmatic opt-in by adding `require 'gssapi/heimdal'` prior to `require 'gssapi'` (for instance, to the code in `winrm/connection.rb`). Unfortunately the support for Heimdal is not well tested, the paths to the Heimdal libraries are currently hard-coded, and the library doesn't account for semantic differences in the Heimdal and MIT implementations of Kerberos APIs, which can cause segfaults.

Samba also has optional experimental support for compiling against MIT Kerberos instead of the default Heimdal.

#### MIT Kerberos

[MIT Kerberos](https://web.mit.edu/kerberos/) is the default implementation used in Linux, and there is some general information on the [client installation instructions page](https://web.mit.edu/Kerberos/www/krb5-latest/doc/admin/install_clients.html).

##### RHEL

RHEL typically installs with the following packages

> yum install krb5-workstation krb5-libs krb5-auth-dialog

RedHat maintains docs about [Configuring a Kerberos 5 client](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/managing_smart_cards/configuring_a_kerberos_5_client)

##### Ubuntu

Ubuntu typically installs with the following packages

> apt-get install krb5-user libpam-krb5 libpam-ccreds auth-client-config

Canonical maintains docs about running a [Kerberos Linux Client](https://help.ubuntu.com/lts/serverguide/kerberos.html#kerberos-linux-client)

#### Microsoft Kerberos

Microsoft Kerberos is built-in to Windows and most easily consumed transparently by domain joining computers to Active Directory.

Microsoft provides some guidance around [SSPI/Kerberos Interopability with GSSAPI](https://docs.microsoft.com/en-us/windows/win32/secauthn/sspi-kerberos-interoperability-with-gssapi) that covers how to map gssapi calls to their equivalent Windows APIs.

### Kerberos Tooling

On Linux and OSX, regardless of the package in use, client configuration is typically stored in `/etc/krb5.conf` (overridable with the `KRB5_CONFIG` environment variable). Windows Active Directory does not use such a config file.

Important client tools include:

* `kinit` for acquiring tickets (not used on Windows)
* `klist` for listing tickets
* `kdestroy` for destroying tickets (not used on Windows)

#### Example Usage

Manual verification of Bolt can be performed from a Linux node that is domain joined to Active Directory using the following steps:

- Set the default winrm authentication to specify the domain in `~/puppetlabs/bolt/inventory.yaml` like:

```yaml
winrm:
  realm: DOMAIN.COM
```

- `kinit -C Administrator@domain.com` to acquire a TGT (ticket granting ticket)
- `bolt command run 'whoami' --targets winrm://dc.domain.com` to connect over HTTPS (`--no-ssl-verify` might be required if the target uses a self-signed certificate)
- `bolt command run 'whoami' --targets winrm://dc.domain.com --no-ssl` to connect over HTTP

### Testing with Docker

In Bolt testing atop Docker containers, [Samba server](https://www.samba.org/) is setup on Linux to approximate an Active Directory setup, which also includes DNS and LDAP support. Given Kerberos has very strict requirements around computer identity (via DNS), Docker user-defined networks with custom DNS and subnets are easier to setup than running in an arbitrary network environment. This lends itself well to an automated and reproducable ephemeral Kerberos environment.

[OMI Server](https://github.com/microsoft/omi) requires the additional Active Directory-like features beyond just a KDC to enable Kerberos based authentication. OMI provides a PowerShell WinRM endpoint on Linux that is intended to behave like the equivalent Windows endpoint.

This environment is intended to support multiple environments:

* [GitHub Actions automated testing](#github-actions-automated-testing)
* [Local development](#local-development)

#### Container Setup

The current `spec/docker-compose.yml` supports a number of containers, many of which are intended to be built when started. For Kerberos, build / start just the relevant containers:

`docker-compose -f spec/docker-compose.yml up -d --build samba-ad omiserver`

##### Samba AD (KDC)

A Kerberos server is provided by running an Alpine container with Samba as an [Active Directory domain controller](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller). The Kerberos realm is `BOLT.TEST`, Active Directory domain is `BOLT.TEST` (short name `BOLT`) and DNS suffix is `bolt.test`

This container provides DNS and LDAP support, but does not contain NTP as that is already provided in a Docker environment. It also hosts a variety of [other services](https://wiki.samba.org/index.php/Samba_AD_DC_Port_Usage) including:

###### External Ports / Services

* 88 (tcp/udp) - Kerberos authentication system
* 464 (tcp/udp) - Kerberos kpasswd (change / set password)

###### Internal Ports / Services

* 53 (tcp/udp) - DNS
* 135 (tcp) - End Point Mapper (DCE/RPC locator service) - remote management of DHCP, DNS, WINS
* 137 (udp) - NetBIOS Name Service
* 138 (udp) - NetBIOS Datagram
* 139 (tcp) - NetBIOS Session Service
* 389 (tcp/udp) - LDAP (Lightweight Directory Access Protocol)
* 445 (tcp) - Microsoft-DS Active Directory / SMB sharing
* 636 (tcp) - LDAP over TLS
* 3268 (tcp) - msft-gc Microsoft Global Catalog (LDAP service for AD forests)
* 3269 (tcp) - msfg-gc-ssl Microsoft Global Catalog over SSL
* 49152-65535 - Dynamic RPC ports

###### Interactive Shell Access

To access the shell, use `/bin/sh` like:

> docker-compose -f spec/docker-compose.yml exec samba-ad /bin/sh

Useful tooling on the instance for managing Active Directory includes:

* [`samba-tool`](https://www.samba.org/samba/docs/current/man-html/samba-tool.8.html) - primary Samba admin tool
* [`net`](https://www.samba.org/samba/docs/current/man-html/net.8.html) - designed to work like the `net` tool on Windows

##### OMI Server

An Ubuntu container running OMI server and listening on both the HTTP and HTTPS WinRM endpoints is intended to simulate a Windows host in a non-Windows environment.

On startup, the container is automatically domain joined to the Samba active directory and is reachable inside the UDN as `omiserver.bolt.test`. As with the Samba container, add an entry to `/etc/hosts` to be able to access it via DNS name from the Docker host environment.

On startup, the Docker entrypoint script waits for the domain to be resolved via DNS and accessible before attempting to perform a domain join with `realm join` followed by `net ads join` (after configuring local Kerberos and Samba clients). The [`sssd`](https://docs.pagure.org/SSSD.sssd/) service is setup to use the [`ad provider`](https://docs.pagure.org/SSSD.sssd/users/ad_provider.html) so that it can look up domain accounts locally.

To configure OMI server the `HTTP` service SPN is added to the `OMISERVER$` computer account in Active Directory, and the `sssd` service is restarted. The [OMI setup documentation](https://github.com/Microsoft/omi/blob/master/Unix/doc/setup-kerberos-omi.md#on-the-server-add-the-http-principal) covers this, but the actual scripts vary a bit since Samba is being used rather than Active Directory.

The container performs a basic validation using `getent passwd administrator@BOLT.TEST` to verify the system is properly configured and domain joined. It then uses the `omicli` tool and the PowerShell cmdlet `Invoke-Command` to vet that the `bolt:bolt` account can authenticate properly using SPENGO. The domain Administrator account is then tested with the same tools to verify Kerberos authentication is working properly.

###### External Ports

* 45985 (tcp) - WinRM HTTP (internally 5985)
* 45986 (tcp) - WinRM HTTPS (internally 5986)

###### Interactive Shell Access

To access the shell, use `/bin/bash` like:

> docker-compose -f spec/docker-compose.yml exec omiserver /bin/bash

Useful tooling on the instance includes:

* [`host`](https://linux.die.net/man/1/host) - DNS lookup utility
* [`klist`](https://web.mit.edu/kerberos/krb5-devel/doc/user/user_commands/klist.html) - check Kerberos tickets
* [`realm`](https://www.systutorials.com/docs/linux/man/8-realm/) - manages enrollment in Kerberos realms and Active Directory domains
* [`net`](https://www.samba.org/samba/docs/current/man-html/net.8.html) - designed to work like the `net` tool on Windows
* [`pwsh`](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-6) - PowerShell 6
* [`omicli`](https://github.com/microsoft/omi/blob/master/Unix/cli/examples.txt) - client tool used to verify basic OMI server functionality

#### GitHub Actions automated testing

At present, GitHub Actions setup will:

* Ensure that it can refer to itself as `samba-ad.bolt.test` and `omiserver.bolt.test` (the same name that the containers refer to themselves inside the Docker UDN)
* Install the Kerberos client package
* Configure the Kerberos client with the approriate server (`samba-ad.bolt.test`) for the realm `BOLT.TEST`

Automated tests (in `spec/bolt/transport/winrm_spec.rb`) verify that the correct TGT (ticket granting ticket) can be acquired from the Samba AD using `kinit` using the domain administrator account `Administrator@BOLT.TEST`.

Despite having a correctly setup environment where OMI server can authenticate against Active Directory with Kerberos, the relevant tests are still marked pending due to a bug in interoperability between the winrm gem and OMI server. [BOLT-1476](https://tickets.puppetlabs.com/browse/BOLT-1476) captures the work remaining to get the tests passing.

#### Local development

To run tests locally on Linux or OSX requires that the local Kerberos client be configured in the same way that CI is, which includes:

* making sure `/etc/krb5.conf` is configured for realm
* the DNS name of `samba-ad.bolt.test` resolves, which requires adding it to `/etc/hosts` as `127.0.0.1 samba-ad.bolt.test`

#### Connecting to OMI from PowerShell

If the Powershell cmdlets [Invoke-Command](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/invoke-command?view=powershell-6) or [Enter-PSSession](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/enter-pssession?view=powershell-6) are used to connect to OMI server, note that PowerShell has different authentication support based on platform:

* OMI server itself is not setup to support basic authentication over HTTP
* Windows PowerShell fully supports Kerberos
* Linux PowerShell appears to support Kerberos, but there is [work to move to a managed library](https://github.com/PowerShell/PowerShell/issues/8233) eventually which is not complete as of PowerShell 6.2
* [OSX PowerShell does not support Kerberos](https://github.com/PowerShell/PowerShell/issues/3708#issuecomment-487785907)

##### Configuring `krb5.conf`

###### Linux

Use the script `spec/fixtures/samba-ad/kerberos-client.config.sh` to generate a `krb5.conf`, which expects the environment variables:

* `KRB5_CONFIG` - optionally used by Kerberos itself to find the config file. Set to a different path like `/tmp/krb5.conf` to not modify the default existing `/etc/krb5.conf` should it already exist
* `KRB5_REALM` - should be set to `BOLT.TEST`
* `KRB5_KDC` - should be set to `samba-ad.bolt.test`
* `KRB5_ADMINSERVER` (optional) - will use `KRB5_KDC` if not set

###### OSX

OSX is slightly different since Docker network ports are not available over UDP. Rather than using the helper script, a sample configuration file is provided at `spec/fixtures/samba-ad/krb5.osx.conf` that forces Kerberos to use only TCP.

##### Validation

Once DNS and the Kerberos client are properly configured, `kinit` can be used to acquire a ticket from Active Directoy like:

> echo 'B0ltrules!' | kinit Administrator@BOLT.TEST

To remove the ticket, use:

> kdestroy --credential=krbtgt/BOLT.TEST@BOLT.TEST

### Advanced: Debugging Bolt + OMI

#### Building OMI server from source

When debugging interoperability problems between the winrm gem and OMI server, it might be necessary to build OMI server from source, rather than consuming packages. This makes it easy to modify OMI server code, rebuild and start using it immediately. When starting the containers, add the build arg `BUILD_OMI=true` like:

> docker-compose -f spec/docker-compose.yml build --build-arg BUILD_OMI=true samba-ad omiserver
> docker-compose -f spec/docker-compose.yml up -d --build samba-ad omiserver

This will:

* install vim
* install all necessary dev / build tooling
* clone source from https://github.com/Microsoft/omi to `/tmp/omi`
* write the script `/build-omi.sh` inside the container
* increase sssd log output
* tail sssd logs and OMI messages in addition to OMI logs

##### `/build-omi.sh`

Run this script at any point after making changes to the source in `/tmp/omi` to build and redeploy OMI server. This will also make sure that the OMI `loglevel` config setting is set to `VERBOSE`

##### OMI source notes

In some cases, OMI server source has to be modified to increase log output, in addition to the `loglevel` change thats already been made. One such example is [Unix/sock/sock.c](https://github.com/microsoft/omi/blob/master/Unix/sock/sock.c#L39-L41), where values must be uncommented like:

```
# define ENABLE_TRACING 1
# define TRACING_LEVEL 4
```

#### Bolt Development Environment

In addition to building OMI from source, it can be useful to run the Bolt source from a Linux agent to iterate on Bolt itself. To really vet Kerberos, this should be performed on a separate container image from the Samba Active Directory controller or the OMI server. This new dev container is defined in `spec/docker-compose-dev.yml` and can be built in addition to the other relevant containers by running `docker-compose`:

> docker-compose -f spec/docker-compose.yml -f spec/docker-compose-dev.yml build --build-arg BUILD_OMI=true samba-ad omiserver linuxdev
> docker-compose -f spec/docker-compose.yml -f spec/docker-compose-dev.yml up samba-ad omiserver linuxdev

This will:

* Provision Ubuntu 18.04
* Join the Samba domain just like OMI server
* Verify pwsh can use all authentication mechanisms against OMI
* Expose port 422 on the Docker host for SSH access
* Install vim, git, rbenv / ruby 2.7.1 / bundler
* Clone the Bolt source to ~/bolt
* Install all gems with bundler including pry-byebug and pry-stackexplorer
* Provide a test script `/bolt-kerberos-test.sh` that can be used for simple test reproductions using Kerberos, noting that some failures that result are currently expected given incompatibilities between winrm gem and OMI server
