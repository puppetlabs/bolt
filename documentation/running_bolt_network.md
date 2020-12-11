# Run Bolt on network devices

You can run Bolt commands that target network devices in order to configure, provision, and make
other changes to those devices. However, interacting with network devices through Bolt can be
different than interacting with other types of targets. Here are some use cases and workflows that
are useful when executing Bolt against network devices.

## Run multiline commands

Because some devices don't allow you to write files, you might not be able to use `bolt script run`
or `Invoke-BoltScript` to run multiline commands. Instead, you can pass a file to `bolt command run`
or `Invoke-BoltCommand` in order to execute multiline commands.

For example, the following file `configure-vap` configures two virtual access points on a Fortinet
device:

```
config wireless-controller vap
    edit WMI
    set fast-roaming enable
    set external-fast-roaming disable
    set max-client 0
    set voice-enterprise enable
    set fast-bss-transition enable
    set broadcast-suppression dhcp-up dhcp-down dhcp-starvation arp-known arp-unknown arp-reply arp-poison arp-proxy netbios-ns netbios-ds ipv6 all-other-bc
next
    edit WM-GUEST
    set fast-roaming enable
    set external-fast-roaming disable
    set max-client 0
    set broadcast-suppression dhcp-up dhcp-down dhcp-starvation arp-known arp-unknown arp-reply arp-poison arp-proxy netbios-ns netbios-ds ipv6 all-other-bc
end
```

### Execute from the Bolt CLI

To run multiline commands from a file, run Bolt from the directory where the file exists:

_\*nix shell command_

```shell
bolt command run @configure-vap --targets servers
```

_PowerShell cmdlet_

```powershell
Invoke-BoltCommand -Command '@configure-vap' -Targets servers
```

### Execute in a Bolt plan

You can provide the absolute path to the file or the Puppet file path (`<mymodule>/<myfile>` for
files stored in the `files/` directory of modules on the modulepath) to the `file::read()` plan
function, and pass that output to the `run_command()` plan function.

```
run_command(file::read('/path/to/configure-vap'), $target)
```

## 🧪 Using Puppet network device modules from an apply block

🧪 **Note:** Support for device modules is experimental and might change in
future minor (y) releases.

[Bolt plans](plans.md) can execute Puppet code from [apply
blocks](applying_manifest_blocks#applying-manifest-blocks-from-a-puppet-plan), including applying
classes from Puppet network device modules like the [PanOS
module](https://forge.puppet.com/modules/puppetlabs/panos). Puppet device modules based on
remote transports allow network devices and other targets that can't run a Puppet agent to be
managed from a proxy. Check out the [Puppet
Forge](https://forge.puppet.com/modules?utf-8=%E2%9C%93&page_size=25&sort=rank&q=network&endorsements=partner+supported)
to find an up to date list of modules for managing network devices.

To use device modules from an apply statement, you must add the devices to the
Bolt inventory as remote targets. The `name` of the target will be used to
auto-populate the `name`, `uri`, `user`, `password`, `host`, and `port` fields
of the remote transport's connection info. You must set the `remote-transport`
option and any other connection info under the `remote` section of config.

```yaml
targets:
  - name: "https://username:password@panos-device.example.com"
    config:
      transport: remote
      remote:
        remote-transport: panos
```

When you set the `run-on` option with a device module, the `puppet-resource_api`
Gem must be installed with the Puppet agent on the proxy target and it must be
version 1.8.1 or later.
