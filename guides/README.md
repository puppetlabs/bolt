# Topic guides

Topic guides are concise descriptions of Bolt's features and concepts with links
to relevant documentation. They act as a reference for users who are looking to
better understand Bolt's features and concepts and quickly get to the
information they are looking for.

## Adding new topic guides

To add a new topic guide, create a text file with the name `<topic>.txt` in this
directory. Topics should be a single word containing only lowercase letters. The
format for a guide should follow the same format as existing guides.

## Adding guides to Bolt packages

During the packaging process, Bolt will typically include all guides in this
directory automatically. However, an extra step is required when adding new
guides to ensure they are added to the Bolt PowerShell module when building the
Windows package.

To add a guide to the Bolt PowerShell module, you will need to add the file as a
WiX component in `bolt-vanagon`, the tool used to build Bolt packages. To add a
component, modify the following XML and add it to [this
file](https://github.com/puppetlabs/bolt-vanagon/blob/main/resources/windows/wix/powershell.wxs.erb):

```xml
<Component
  Id="about_bolt_<TOPIC>.help.txt"
  Directory="PowerShellBoltModuleHelpDir"
  Guid="<GUID>">
  <File
    Id="about_bolt_<TOPIC>.help.txt"
    Source="$(var.AppSourcePath)\share\PowerShell\Modules\PuppetBolt\en-US\about_bolt_<TOPIC>.help.txt"
    KeyPath="yes" />
</Component>
```

> **Note:** Replace `<TOPIC>` with the name of the new topic and `<GUID>` with a
> Globally Unique Identifier (GUID). You can generate a GUID in PowerShell using
> the `Get-Guid` cmdlet.

Once you have modified this file, open a [pull request against
`bolt-vanagon`](https://github.com/puppetlabs/bolt-vanagon/pulls).
