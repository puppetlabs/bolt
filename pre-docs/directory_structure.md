# Directory structures for task and plan development

Bolt looks for tasks and plans following the structure of a [Puppet module](https://puppet.com/docs/puppet/latest/modules_fundamentals.html). The [Puppet Development Kit (PDK)](https://puppet.com/download-puppet-development-kit) can be used to create Puppet modules and add tasks to it.

A typical module for use with Bolt may contain:
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
    Contains Hiera data that can be used when applying a manifest block.
`files/`
    Contains static files that can be loaded by a plan or required as a dependency of a task. Prefer putting non-Ruby libraries used by a task here.
`hiera.yaml`
    The Hiera configuration for this module. See the [Hiera docs](https://puppet.com/docs/puppet/latest/hiera.html).
`lib/`
    Typically Ruby code such as custom Puppet functions that can be called by a plan or library code used by a task.
`manifests/`
    Classes and other Puppet code usable when applying a manifest block.
`metadata.json`
    Typical metadata for a Puppet module describing version, OS compatibility, and other module dependencies.
`plans/`
    Contains plans, which must end in the `.pp` extension.
`tasks/`
    Contains tasks and their metadata.

## Developing a module

When creating a module, it's useful to run the tasks and plans you write as well as write automated tests for them.

To run a plan, you'll need to declare the modulepath to find them. Typically this is done with `bolt --modulepath ..` to specify the parent of the module directory you're working in. Any dependencies you require should either be in the same parent directory or in other directories specified as additional modulepath entries.

Automated testing patterns are not yet documented, but https://github.com/puppetlabs/puppetlabs-facts is a typical example of unit testing plans and integration (acceptance) testing tasks. The blog post [Writing Robust Puppet Bolt Tasks: A Guide](https://puppet.com/blog/writing-robust-puppet-bolt-tasks-guide).

Once the module is created and published to a code repository or the [Puppet Forge](https://forge.puppet.com), others can install it as described in [Installing modules](bolt_installing_modules.md#).

## Project-specific tasks and plans

Tasks and plans developed to support a particular project can be included with that project in a [Boltdir](https://puppet.com/docs/bolt/1.x/configuring_bolt.html) at the root of the project.

A typical project including a Boltdir will look as follows:
```

├── Boltdir
│   ├── Puppetfile
│   └── site/
│       └── project/
└── other_project_files
```

Your tasks and plans would go in the `Boltdir/site/project/tasks` and `Boltdir/site/project/plans` directories.

The `Puppetfile` declares modules you depend on. Within the project, run `bolt puppetfile install` to install dependencies to the `Boltdir/modules/` directory. Running within the project will see `Boltdir` and look in the default modulepath (`Boltdir/site/` and `Boltdir/modules/`) for modules containing Bolt content.

## Self-contained projects (the control repository pattern)

The control repository pattern is useful for creating a project that contains your tasks and plans - along with declaring modules they depend on - for others to run. It's based on the idea originally [developed for Puppet](https://github.com/puppetlabs/best-practices/blob/master/control-repo-contents.md) of a repository that acts as a single location for an organization's configuration. The base example can be found [here](https://github.com/puppetlabs/control-repo).

In Bolt, the control repository can also act as the [Boltdir](https://puppet.com/docs/bolt/1.x/configuring_bolt.html). To do so, add `bolt.yaml` (it can be an empty file) to the root of the repository.

A typical control repository for running plans will look as follows:
```

├── bolt.yaml
├── data/
├── hiera.yaml
├── Puppetfile
├── README.md
└── site/
    ├── profile/
```

Your tasks and plans would go in the `site/profile/tasks` and `site/profile/plans` directories. `hiera.yaml` is used when [applying manifest code](applying_manifest_blocks.md#) and can also be placed within the module at `site/profile/`.

The `Puppetfile` declares modules you depend on. Within the control repository, run `bolt puppetfile install` to install dependencies to the `modules/` directory. Running within this directory will see `bolt.yaml`, interpret it as a `Boltdir`, and look in the default modulepath (`site/` and `modules/`) for modules containing Bolt content.
