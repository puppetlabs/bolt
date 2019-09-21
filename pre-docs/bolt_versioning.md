# Bolt versioning

Bolt follows Semantic Versioning guidelines.

This system uses an "x.y.z" pattern, where "x" is the number of a major release, "y" indicates a minor release that introduces new features but does not include breaking changes, and "z" reflects a bug fix release.

## Bolt API

The 1.0 series of Bolt is stable and will be free of breaking changes to it's public API. In general this means that plans, inventory and config tested with one 1.y series release of Bolt will continue to work when used with a newer 1.y series release. There will however be new functionality added in the 1.0 series. You can expect the following types of changes:

-   New keys in JSON format output.

-   Differences in log output and human format output.

-   New methods added to plan Data Type Objects.

-   New options added to plan functions.

-   Support for new revisions of the task spec and newer tasks.

-   Versions of bundled modules will be updated and may include breaking changes.


## Bolt Releases

For the 1.y series of Bolt we do not plan to backport bug fixes to any previously released version. You are encouraged to upgrade frequently and use the latest release.

**Related information**  


[Semantic Versioning](https://semver.org/)

