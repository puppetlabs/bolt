# Directory structures for tasks and plans

Follow these guidelines for writing and sharing projects that use tasks and plans.

There are several ways that you might deploy tasks and plans, depending on how you want to use or share them. You can deploy tasks and plans as:
* A standalone module that you publish, for example to the Forge.
* A module that's part of a project you want to deploy.
* A module that's part of a control repository.

Regardless of how you deploy your tasks and plans, they must be structured as a module.

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

## Standalone modules

Standalone modules can be published to the Forge or saved in a local code repository. When you create a standalone module, be sure all dependencies are specified in the modulepath.

To run a plan, you must declare the modulepath to find it, typically with `bolt --modulepath ..` where `modulepath` specifies the parent of the module directory you're working in. Any dependencies required to run the plan must either be in the same parent directory or in additional directories specified as modulepath entries.

> **Tip**: As a best practice, write automated tests for the tasks and plans in your module, if possible. For information about automated testing patterns, check out these resources:
> * [Example of unit testing plans and integration (acceptance) testing tasks](https://github.com/puppetlabs/puppetlabs-facts) (GitHub)
> * [Writing Robust Puppet Bolt Tasks: A Guide](https://puppet.com/blog/writing-robust-puppet-bolt-tasks-guide) (Puppet blog)



## Modules for projects

Tasks and plans developed to support a particular project can be included with that project in a `Boltdir` at the root of the project.

A typical project including a `Boltdir` is structured like this:
```

├── Boltdir
│   ├── Puppetfile
│   └── site/
│       └── project/
└── other_project_files
```

Tasks and plans go in the `Boltdir/site/project/tasks` and `Boltdir/site/project/plans` directories, respectively.

The Puppetfile declares modules that your tasks and plans depend on. Within the project directory, run `bolt puppetfile install` to install dependencies to the `Boltdir/modules/` directory. When you run tasks and plans within the project, the `Boltdir` is detected and the default modulepaths (`Boltdir/site/` and `Boltdir/modules/`) are searched for modules containing Bolt content.

Related information
[Configuring Bolt](configuring_bolt.md)

## Modules in control repositories

The control repository pattern is useful for sharing tasks and plans — and the modules they depend on — with others.

Your organization's centralized control repository can also act as your `Boltdir` by adding `bolt.yaml` to the root of the repository. The `bolt.yaml` can be an empty file. For more information about setting up a centralized control repository for your organization, see [best practices for control repositories](https://github.com/puppetlabs/best-practices/blob/master/control-repo-contents.md) and a corresponding [example](https://github.com/puppetlabs/control-repo).

A typical control repository for running plans is structured like this:
```

├── bolt.yaml
├── data/
├── hiera.yaml
├── Puppetfile
├── README.md
└── site/
    ├── profile/
```

Tasks and plans go in the `site/profile/tasks` and `site/profile/plans` directories, respectively. The `hiera.yaml` file is used when [applying manifest code](applying_manifest_blocks.md) and can also be placed within the module at `site/profile/`.

The Puppetfile declares modules that your tasks and plans depend on. Within the control repository, run `bolt puppetfile install` to install dependencies to the `modules/` directory. When you run tasks and plans within the control repository, the `bolt.yaml` file is interpreted as a `Boltdir`, and the default modulepaths (`site/` and `modules/`) are searched for modules containing Bolt content.
