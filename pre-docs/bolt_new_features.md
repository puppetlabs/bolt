# New features

New features added to Bolt in the 1.x release series. 

## Share code between tasks \(1.1.0\)

Bolt includes the ability to share code between tasks. A task can include a list of files that it requires, from any module, that it copies over and makes available via a \_installdir parameter. This feature is also supported in Puppet Enterprise 2019.0. For more information see, [Sharing task code](writing_tasks.md#). \([BOLT-755](https://tickets.puppetlabs.com/browse/BOLT-755)\)

## Upgraded WinRM gem dependencies \(1.1.0\)

The following gem dependencies have been upgraded to fix the connection between OMI server on Linux and the WinRM transport:

-   winrm 2.3.0

-   winrm-fs 1.3.1

-   json-schema 2.8.1


\([BOLT-929](https://tickets.puppetlabs.com/browse/BOLT-929)\)

## Mark internal tasks as private \(1.1.0\)

In the task metadata, you can mark internal tasks as private and prevent them from appearing in task list UIs. \([BOLT-734](https://tickets.puppetlabs.com/browse/BOLT-734)\)

## Upload directories via plans \(1.1.0\)

The `bolt file upload` command and `upload_file` action now upload directories. For use over the PCP transport these commands require puppetlabs-bolt\_shim 0.2.0 or later. \([BOLT-191](https://tickets.puppetlabs.com/browse/BOLT-191)\)

## Support for public-key signature system ed25519 \(1.1.0\)

The ed25519 key type is now supported out-of-the-box in Bolt packages. \([BOLT-380](https://tickets.puppetlabs.com/browse/BOLT-380)\)

