# Bolt versioning

Bolt follows semantic versioning guidelines.

This system uses an "x.y.z" pattern, where "x" is the number of a major release, "y" indicates a minor release that introduces new features but does not include breaking changes, and "z" reflects a bug fix release.

## Bolt API

The 1.0 series of Bolt is stable and be free of breaking changes to its public API. In general this means that plans, inventory and config tested with one 1.y series release of Bolt continues to work when used with a newer 1.y series release. There is, however, new functionality added in the 1.0 series. You can expect the following types of changes:

-   New keys in JSON format output.

-   Differences in log output and human format output.

-   New methods added to plan Data Type Objects.

-   New options added to plan functions.

-   Support for new revisions of the task spec and newer tasks.

-   Versions of bundled modules are updated and might include breaking changes.


## Bolt Releases

For the 1.y series of Bolt we do not plan to backport bug fixes to any previously released version. You are encouraged to upgrade frequently and use the latest release.

**Parent topic:**[Bolt release notes](bolt_release_notes.md)

**Related information**  


[Semantic Versioning](https://semver.org/)

