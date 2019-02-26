# Directory structures for tasks and plans

Puppet Tasks, Plans, Functions, Classes and Types, must exist inside a Puppet
Module for Bolt to load them. Bolt loads modules by searching for module
directories on the modulepath. By default the `modulepath` includes the `modules/` and
`site-modules` directories in the [Bolt project directory](./bolt_project_directory.md).


## Directory structure of a module

A module is a sub-directory of one of the directories on the modulepath. In
order for Bolt to load Tasks and Plans they must exist in the `tasks/` or
`plans/` directory of a module with the correct name.

> **Tip**: You can use the Puppet Development Kit (PDK) to create modules and add tasks to it.

A typical module for use with Bolt may contain these directories:
```

├── data/
├── files/
├── hiera.yaml
├── lib/
├── manifests/
├── metadata.json
├── plans/
└── tasks/
```

`data/`
    Hiera data that can be used when applying a manifest block.
`files/`
    Static files that can be loaded by a plan or required as a dependency of a task. Prefer putting non-Ruby libraries used by a task here.
`functions/`
    Puppet Language functions that can be used from a plan.
`hiera.yaml`
    Hiera configuration for this module.
`lib/`
    Typically Ruby code, such as custom Puppet functions, types, or providers.
`manifests/`
   Classes and other Puppet code usable when applying a manifest block.
`metadata.json`
    Typical metadata for a module describing version, operating system compatibility, and other module dependencies.
`plans/`
    Plans, which must end in the `.pp` extension.
`tasks/`
    Tasks and their metadata.

### Where to put module code

Modules can either be written directly in `site-modules/` or be installed from
the Puppet Forge or a code repository into `modules/`.

## Modules for projects

Modules developed to support a particular project can be developed directly in
the `site-modules` directory of the [Bolt project
directory](./bolt_project_directory.md). Create a new directory for each module
inside `site-modules` that matches the modules name or use [`pdk new
module`](https://puppet.com/docs/pdk/latest/pdk.html) to create a skeleton
structure.

## Standalone modules

Standalone modules can be published to the Forge or saved in a shared code
repository. This allows a module to be used from multiple projects or shared
publicly. To use a standalone module install it into the project directory as
described in [Installing Modules](./bolt_installing_modules.md)

To create a standalone module run `pdk new module` outside of the project
directory, develop the module then push it to a code repository or the Puppet
Forge before using it in your project. Read [The Beginners Guide to Writing
Modules](https://puppet.com/docs/puppet/latest/bgtm.html) for more information
about writing standalone modules.

Follow these tips for managing standalone modules:

* Add `modules/*` to `.gitignore` of your project to prevent accidentally committing standalone modules.
* When you run tasks and plans within a project directory, the modulepath (`modules/` and `site-modules/`) is searched for modules containing Bolt content. If a module is found in `modules` tasks and plans from the version of the module in `site-modules` are ignored. Remove a module from `site-modules` if you convert it to a standalone module.
* As a best practice, write automated tests for the tasks and plans in your module, if possible. For information about automated testing patterns, check out these resources: [Example of unit testing plans and integration (acceptance) testing tasks](https://github.com/puppetlabs/puppetlabs-facts) (GitHub) and [Writing Robust Puppet Bolt Tasks: A Guide](https://puppet.com/blog/writing-robust-puppet-bolt-tasks-guide) (Puppet blog)
