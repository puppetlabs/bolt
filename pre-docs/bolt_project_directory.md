# Bolt Project Directory

Bolt runs in the context of a Bolt project directory or a `Boltdir`. This
directory contains all of the configuration, code and data loaded by Bolt.
This structure makes it easy to share Bolt code by committing the project
directory to Git. You can then check different repositories of Bolt code into
different directories in order to manage various applications.

## Types of Project Directory

There are three types of project directories that can be used depending on how
you're using Bolt.

### Local Project Directory

Bolt treats a directory containing a `bolt.yaml` as a project directory. Use
this type of project directory to track and share management code in a
dedicated repository.

A project directory of this type has a structure like:
```
project/
├── Puppetfile
├── bolt.yaml
├── data
│   └── common.yaml
├── inventory.yaml
└── site-modules
    └── project
        ├── manifests
        │   └── my_class.pp
        ├── plans
        │   ├── deploy.pp
        │   └── diagnose.pp
        └── tasks
            ├── init.json
            └── init.py
```

> **Tip**: You can use an existing control repo as a Bolt project directory by
> adding a `bolt.yaml` file to it and configuring the `modulepath` to match the
> `modulepath` in `environment.conf`

### Embedded Project Directory

Bolt treats a directory containing a subdirectory called `Boltdir` as a project
directory. Use this type of project directory to embed Bolt management code
into another repo. For example you can store management code in the same repo
as the application it manages without cluttering up the top level with multiple
files. This will allow you to run Bolt from anywhere in the applications
directory structure.

A project with an embeded project directory has a structure like:
```
project/
├── Boltdir
│   ├── Puppetfile
│   ├── bolt.yaml
│   ├── data
│   │   └── common.yaml
│   ├── inventory.yaml
│   └── site-modules
│       └── project
│           ├── manifests
│           │   └── my_class.pp
│           ├── plans
│           │   ├── deploy.pp
│           │   └── diagnose.pp
│           └── tasks
│               ├── init.json
│               └── init.py
├── src <non Bolt source code for the project>
└── tests <non Bolt tests for the project>
```

**note** If a directory contains both `Boltdir` and `bolt.yaml` the `Boltdir`
directory will be used as the project directory rather then the parent.


### User Project Directory

If Bolt cannot find a project directory based on `Boltdir` or `bolt.yaml` it
will use `~/.puppetlabs/bolt` as the project directory. Use this type of
project directory if you have a single set of Bolt code and data you use
across all projects.

### How the project directory is chosen

The following methods are used by Bolt in priority order to choose a project directory.

#. Manually specified: You can specify what directory Bolt should use with
   `--boltdir <directory path>` on the command line. There is not an equivalent
   configuration setting because the Bolt project directory needs to be known to
   load configuration.

#. Parent directory: Bolt will traverse parents of the current directory until
   it finds a directory containing a `Boltdir` or `bolt.yaml` or it reaches the
   root of the file system.

#. User Project Directory: If no directory is specified manually or found in a
   parent the user project directory will be used.

## Structure of the project directory

The default paths for all of Bolt's configuration, code and data are relative to the modulepath.

* [`bolt.yaml`](./bolt_configuration_options.md) contains configuration options for Bolt.
* `hiera.yaml` the hiera config to use for node specific data when using `apply`
* [`inventory.yaml`](./inventory_file.md) contains a list of known targets and target specific data.
* [`Puppetfile`](`./bolt_installing_modules.md`) This file specifies which Puppet Modules should be installed for the project.
* [`modules/`](./bolt_installing_modules.md) Bolt will install modules from the `Puppetfile` into this directory. In most cases these modules should not be edited locally.
* [`site-modules/`](./writing_tasks_and_plans.md) Local modules that are edited and versioned with project directory.
* `data/` The standard path to store static hiera data files.
