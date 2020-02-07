# Bolt versions

Bolt follows [semantic versioning](https://semver.org/) guidelines.

This system uses an "x.y.z" pattern, where "x" is the number of a major release, "y" indicates a minor release that introduces new features but does not include breaking changes, and "z" reflects a bug fix release.


## Bolt API

The 2.0 series of Bolt is stable and will be free of breaking changes to its public API. In general this means that plans, inventory and config tested with any 1.y series release of Bolt will continue to work when used with a later 2.y series release. You can expect the following types of changes in the 2.0 series:

-   New keys in JSON format output.
-   Differences in log output and human format output.
-   New methods added to plan Data Type Objects.
-   New options added to plan functions.
-   Support for new revisions of the task spec and newer tasks.
-   Versions of bundled modules will be updated and might include breaking changes.


## Bolt releases

For the 2.y series of Bolt we do not plan to backport bug fixes to any previously released version. You are encouraged to upgrade frequently and use the latest release.

