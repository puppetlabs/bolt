# Project directories

Bolt runs in the context of a project directory or a `Boltdir`. This directory contains all of the configuration, code, and data loaded by Bolt.

The project directory structure makes it easy to share Bolt code by committing the project directory to Git. You can then check different repositories of Bolt code into different directories in order to manage various applications.

## Types of project directories

There are three types of project directories that you can use depending on how you're using Bolt.

### Local project directory

Bolt treats a directory containing a `bolt.yaml` file as a project directory. Use this type of directory to track and share management code in a dedicated repository.

**Tip:** You can use an existing control repo as a Bolt project directory by adding a `bolt.yaml` file to it and configuring the `modulepath` to match the `modulepath` in `environment.conf`.

A project directory of this type has a structure like:

```console
project/
├── Puppetfile
├── bolt.yaml
├── data
│   └── common.yaml
├── inventory.yaml
├── project.yaml
└── site-modules
    └── project
        ├── manifests
        │   └── my_class.pp
        ├── plans
        │   ├── deploy.pp
        │   └── diagnose.pp
        └── tasks
            ├── init.json
            └── init.py
```

### Embedded project directory

Bolt treats a directory containing a subdirectory called `Boltdir` as a project directory. Use this type of directory to embed Bolt management code into another repo.

For example, you can store management code in the same repo as the application it manages without cluttering up the top level with multiple files. This structure allows you to run Bolt from anywhere in the application's directory structure.

A project with an embedded project directory has a structure like:

```console
project/
├── Boltdir
│   ├── Puppetfile
│   ├── bolt.yaml
│   ├── data
│   │   └── common.yaml
│   ├── inventory.yaml
│   └── site-modules
│       └── project
│           ├── manifests
│           │   └── my_class.pp
│           ├── plans
│           │   ├── deploy.pp
│           │   └── diagnose.pp
│           └── tasks
│               ├── init.json
│               └── init.py
├── src #non Bolt source code for the project
└── tests #non Bolt tests for the project
```

**Note:** If a directory contains both `Boltdir` and `bolt.yaml`, the `Boltdir` directory is used as the project directory rather then the parent.

### User project directory

If Bolt can't find a project directory based on `Boltdir` or `bolt.yaml`, it uses `~/.puppetlabs/bolt` as the project directory. Use this type of directory if you have a single set of Bolt code and data that you use across all projects.

## How the project directory is chosen

Bolt uses these methods, in order, to choose a project directory.

1.  **Manually specified:** You can specify on the command line what directory Bolt to use with `--boltdir <DIRECTORY_PATH>`. There is not an equivalent configuration setting because the project directory must be known in order to load configuration.
1.  **Parent directory:** Bolt traverses parents of the current directory until it finds a directory containing a `Boltdir` or `bolt.yaml`, or it reaches the root of the file system.
1.  **User project directory:** If no directory is specified manually or found in a parent directory, the user project directory is used.


## Project directory structure

The default paths for all Bolt configuration, code, and data are relative to the modulepath.

|Directory|Description|
|---------|-----------|
|[`bolt.yaml`](bolt_configuration_reference.md)|Contains configuration options for Bolt.|
|`hiera.yaml`|Contains the Hiera config to use for target-specific data when using `apply`.|
|[`inventory.yaml`](inventory_file_v2.md)|Contains a list of known targets and target specific data.|
|[`project.yaml`](bolt_configuration_reference.md#project_configuration_options)|Contains configuration for the Bolt project.  The project.yaml file contains a whitelist of tasks and plans that you can use to limit the output from the `bolt [plan|task] show` command.|
|[`Puppetfile`](bolt_installing_modules.md#)|Specifies which modules to install for the project.|
|[`modules/`](bolt_installing_modules.md#)|The directory where modules from the `Puppetfile` are installed. In most cases, do not edit these modules locally.|
|[`site-modules`](bolt_installing_modules.md)|Local modules that are edited and versioned with the project directory.|
|`data/`|The standard path to store static Hiera data files.|
