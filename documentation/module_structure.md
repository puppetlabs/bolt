# Module structure

Puppet tasks, plans, functions, classes and types must exist inside a Puppet module in order for Bolt to load them. Bolt loads modules by searching for module directories on the modulepath.

By default, the modulepath includes the `modules` and `site-modules` directories
in the [Bolt project directory](bolt_project_directories.md#). If `bolt-project.yaml`
exists at the root of the project directory, the project itself is also
loaded as a module and namespaced to either `name` in `bolt-project.yaml` if it's
set, or the name of the directory if `name` is not set. 

> **Note:** The `bolt-project.yaml` file is part of an experimental feature. For
> more information, see [Bolt projects](./experimental_features.md#bolt-projects).

## Directory structure of a module

A module is a sub-directory of one of the directories on the modulepath. In order for Bolt to load tasks and plans, they must exist in the `tasks/` or `plans/` directory of a module with the correct name.

> 🔩 **Tip:** You can use the Puppet Development Kit (PDK) to create modules and add tasks to it.

A typical module for use with Bolt may contain these directories:

```console
├── data/
├── files/
├── hiera.yaml
├── lib/
├── manifests/
├── metadata.json
├── plans/
└── tasks/
```

|Directory|Contents|
|---------|--------|
|`data`|Hiera data that can be used when applying a manifest block.|
|`files`|Static files that can be loaded by a plan or required as a dependency of a task. Prefer putting non-Ruby libraries used by a task here.|
|`functions`|Puppet language functions that can be used from a plan.|
|`hiera.yaml`|Hiera configuration for this module.|
|`lib`|Typically Ruby code, such as custom Puppet functions, types, or providers.|
|`manifests`|Classes and other Puppet code usable when applying a manifest block.|
|`metadata.json`|Typical metadata for a module describing version, operating system compatibility, and other module dependencies.|
|`plans`|Plans, which must end in the `.pp` extension.|
|`tasks`|Tasks and their metadata.|

### Where to put module code

You can develop modules directly in the Bolt project directory or install them from the Puppet
Forge into the `modules` directory.

## Modules for projects

Modules developed to support a particular project can be developed directly in the Bolt project directory. You can use `pdk new module` to create a skeleton structure, and `bolt project init` inside a directory to make it a Bolt project directory.

**Note**:  To use the `pdk` command, you must [install the Puppet Development Kit](https://puppet.com/docs/pdk/1.x/pdk_install.html) 

## Standalone modules

Standalone modules can be published to the Forge or saved in a shared code repository so that modules can be used from multiple projects or shared publicly.

To use a standalone module, [install the module](bolt_installing_modules.md#) into the project directory.

To create a standalone module, run `pdk new module` outside of the project directory, develop the module, then push it to a code repository or the Forge before using it in your project.

Follow these tips for managing standalone modules:

-   Add `modules/*` to `.gitignore` of your project to prevent accidentally committing standalone modules.
-   When you run tasks and plans within a project directory the modulepath is searched in order for modules containing Bolt content. The Bolt project directory itself is loaded as a module at the front of the modulepath, and the default modulepath is `<project directory>/modules:<project directory>/site-modules`. If you have a module in both the `modules` and `site-modules` directories, the version in `modules` will be used.
-   As a best practice, write automated tests for the tasks and plans in your module, if possible. For information about automated testing patterns, check out these resources: [Example of unit testing plans and integration \(acceptance\) testing tasks](https://github.com/puppetlabs/puppetlabs-facts) (GitHub) and [Writing Robust Puppet Bolt Tasks: A Guide](https://puppet.com/blog/writing-robust-puppet-bolt-tasks-guide) (Puppet blog).
