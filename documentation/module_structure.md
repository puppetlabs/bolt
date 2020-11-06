# Module structure

Before Bolt can load content like tasks, plans, functions, classes and types,
that content must exist inside a Puppet module on the current Bolt project's
modulepath.

By default, the Bolt modulepath includes the `modules` and `.modules`
directories, as well as any project-level content in the current Bolt project
directory. You can create project-level content to use with Bolt, or create a
standalone module that you can install with Bolt and use as you would any other
module you downloaded from the Forge.

## Directory structure of a module

Modules have a specific directory structure outlined in the [Puppet
documentation](https://puppet.com/docs/puppet/latest/modules_fundamentals.html#module_structure).
However, a typical module for use with Bolt may contain these files and directories:

|Directory/File|Contents|
|---------|--------|
|`data`|Hiera data that can be used when applying a manifest block.|
|`files`|Static files that can be loaded by a plan or required as a dependency of a task. Prefer putting non-Ruby libraries used by a task here.|
|`functions`|Puppet language functions that can be used from a plan.|
|`hiera.yaml`|Hiera configuration for this module.|
|`lib`|Typically Ruby code, such as custom Puppet functions, types, or providers.|
|`manifests`|Classes and other Puppet code usable when applying a manifest block.|
|`metadata.json`|Typical metadata for a module describing version, operating system compatibility, and other module dependencies.|
|`plans`|Plans, which must end in the `.pp` or `.yaml` extensions.|
|`tasks`|Tasks and their metadata.|

### Where to put module content

You have two options when it comes to storing and developing module content: 
- You can develop modules directly in the Bolt project directory inside the
  `modules` directory. 
- You can develop your module content outside of a project directory and then
  add the module's directory to your project's modulepath for use with Bolt.
  Alternatively, you can publish the module to the Forge and install it to your
  Bolt project.

## Modules for projects

If you're developing a module to support a particular project, you can develop
the module directly in the Bolt project directory. To create a skeleton
structure for your module, run `pdk new module` inside the `modules` directory
in your project. For information on creating a new project, see [Bolt
projects](./projects.md).

**Note**:  To use the `pdk` command, you must [install the Puppet Development
Kit](https://puppet.com/docs/pdk/1.x/pdk_install.html) 

## Standalone modules

If you want to share a module publicly, you can develop the module outside of a
Bolt project and publish it to the Puppet Forge. If you want to use the module
in multiple Bolt projects, but don't want to publish it, you [can add the
directory that contains the module to your modulepath](modules.md#modulepath).

To create a standalone module and publish it on the Forge:
1. Run `pdk new module` outside of a Bolt project directory.
1. Develop the module.
1. Push the module to a code repository or the Forge.

After you've published the module to the Forge, you can add it to a Bolt project
using the Bolt command line. For more information, see [Installing
modules](./bolt_installing_modules.md).

Follow these tips for managing standalone modules:
-   If you're testing a standalone module inside a project, add `modules/*` to
    the project's `.gitignore` file to prevent accidentally committing the
    module.
-   As a best practice, write automated tests for the tasks and plans in your
    module, if possible. For information about automated testing patterns, check
    out these resources: [Example of unit testing plans and integration
    \(acceptance\) testing
    tasks](https://github.com/puppetlabs/puppetlabs-facts) (GitHub) and [Writing
    Robust Puppet Bolt Tasks: A
    Guide](https://puppet.com/blog/writing-robust-puppet-bolt-tasks-guide)
    (Puppet blog).
