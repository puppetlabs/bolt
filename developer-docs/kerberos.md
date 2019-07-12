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

### Usage

Manual verification of Bolt can be performed from a Linux node that is domain joined to Active Directory using the following steps:

- Set the default winrm authentication to specify the domain in `~/puppetlabs/bolt/bolt.yaml` like:

```yaml
winrm:
  realm: DOMAIN.COM
```

- `kinit -C Administrator@domain.com` to acquire a TGT (ticket granting ticket)
- `bolt command run 'whoami' --targets winrm://dc.domain.com` to connect over HTTPS (`--no-ssl-verify` may be required if the target uses a self-signed certificate)
- `bolt command run 'whoami' --targets winrm://dc.domain.com --no-ssl` to connect over HTTP

In the future, this testing will be automated.
