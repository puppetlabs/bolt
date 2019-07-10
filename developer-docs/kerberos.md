# Bolt + Kerberos

### Overview

Bolt supports using Kerberos as an authentication mechanism, in lieu of a username / password. An excellent background on key Kerberos concepts is available in [Designing an Authentication System: a Dialogue in Four Scenes](https://web.mit.edu/kerberos/www/dialogue.html).

While Linux **does** support a standalone Kerberos KDC (Key Distribution Center), the [`winrm`](https://github.com/WinRb/WinRM) gem that provides connectivity support from Bolt has only been written for and tested against Active Directory.

In the future, it's possible other transports like SSH may be able to authenticate and authorize with just a KDC, but for now, the primary use case for Kerberos is in conjunction with WinRM.

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

- Set the default winrm authentication to specify the domain in `~/puppetlabs/bolt/bolt.yaml` like:

```yaml
winrm:
  realm: DOMAIN.COM
```

- `kinit -C Administrator@domain.com` to acquire a TGT (ticket granting ticket)
- `bolt command run 'whoami' --targets winrm://dc.domain.com` to connect over HTTPS (`--no-ssl-verify` may be required if the target uses a self-signed certificate)
- `bolt command run 'whoami' --targets winrm://dc.domain.com --no-ssl` to connect over HTTP

### Testing with Docker

In Bolt testing atop Docker containers, [Samba server](https://www.samba.org/) is setup on Linux to approximate an Active Directory setup, which also includes DNS and LDAP support. Given Kerberos has very strict requirements around computer identity (via DNS), Docker user-defined networks with custom DNS and subnets are easier to setup than running in an arbitrary network environment. This lends itself well to an automated and reproducable ephemeral Kerberos environment.

[OMI Server](https://github.com/microsoft/omi) requires the additional Active Directory-like features beyond just a KDC to enable Kerberos based authentication. OMI provides a PowerShell WinRM endpoint on Linux that is intended to behave like the equivalent Windows endpoint.

This environment is intended to support multiple environments:

* [TravisCI automated testing](#travisCI-automated-testing)
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

On startup, the Docker entrypoint script waits for the domain to be resolved via DNS and accessible before attempting to perform a domain join with `realm join` followed by `net ads join` (after configuring local Kerberos and Samba clients). The [`sssd`](https://docs.pagure.org/SSSD.sssd/) service is setup to use the [`ad provider`](https://docs.pagure.org/SSSD.sssd/users/ad_provider.html) so that it may look up domain accounts locally.

The container performs a basic validation using `getent passwd administrator@BOLT.TEST` to verify the system is properly configured and domain joined. It then uses the `omicli` tool and the PowerShell cmdlet `Invoke-Command` to vet that the `bolt:bolt` account can authenticate properly.

At this stage, OMI server is not yet configured to use Kerberos authentication, so that connectivity is not verified.

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

#### TravisCI automated testing

At present, Travis setup will:

* Ensure that it can refer to itself as `samba-ad.bolt.test` (the same name that the container refers to itself inside the Docker UDN)
* Install the Kerberos client package
* Configure the Kerberos client with the approriate server (`samba-ad.bolt.test`) for the realm `BOLT.TEST`

Automated tests (in `spec/bolt/transport/winrm_spec.rb`) verify that the correct TGT (ticket granting ticket) can be acquired from the Samba AD using `kinit` using the domain administrator account `Administrator@BOLT.TEST`.

Previously added tests are still marked pending until other infrastructure within Docker is configured to use Kerberos.

#### Local development

To run tests locally on Linux or OSX requires that the local Kerberos client be configured in the same way that Travis is, which includes:

* making sure `/etc/krb5.conf` is configured for realm
* the DNS name of `samba-ad.bolt.test` resolves, which requires adding it to `/etc/hosts` as `127.0.0.1 samba-ad.bolt.test`

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
