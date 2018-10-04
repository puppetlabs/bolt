# Bolt Versioning

Bolt follows semantic versioning guidelines. With the release of Bolt 1.0.0
this means that for future `1.y.z` releases there should be no breaking
changes. New releases with only bug fixes will be `z` releases while those with new features will be `y` releases.

## Bolt API

The 1.0 series of Bolt is stable and will be free of breaking changes to it's
public API. In general this means that plans, inventory and config tested with
one `1.y` series release of bolt will continue to work when used with a newer
`1.y` series release. There will however be new functionality added in the 1.0
series. Bolt users should expect the following types of changes.

* New keys in `json` format output.
* Differences in log output and `human` format output.
* New methods added to plan Data Type Objects.
* New options added to plan functions.
* Support for new revisions of the task spec and newer tasks.
* Versions of bundled modules will be updated and may include breaking changes.

## Bolt Releases

For the `1.y` series of Bolt we do not plan to backport bug fixes to any
previously released version. Bolt users are encouraged to upgrade frequently
and use the latest release.
