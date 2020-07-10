# Project directories

There are two directory structures available to Bolt projects. You can run Bolt inside a
local project directory and share that directory with others using a version control
system like git, or you can embed the project directory inside an application's
repo, and make Bolt available to that application.

## Local project directories

To track and share management code in a dedicated repository, or to run and
develop Bolt content locally, use a local project directory. Bolt recognizes
any directory containing a `bolt-project.yaml` file as a Bolt project directory.

A simple project directory looks like this:

```console
myproject/
├── bolt-project.yaml
├── inventory.yaml
├── plans
│   ├── deploy.pp
│   └── diagnose.pp
└── tasks
    ├── init.json
    └── init.py
```

As long as your `bolt-project.yaml` file contains a `name` field, Bolt loads
your local Bolt content from the top level of your directory. If you're
developing a module for the Puppet Forge, you can use a Puppet module
directory structure. For more information, see [Module
structure](module_structure.md). 


> 🔩 **Tip:** You can use an existing control repo as a Bolt directory by adding
  a `bolt-project.yaml` file to it and configuring the `modulepath` to match the
  `modulepath` in `environment.conf`.

## Embedded project directories

Bolt treats a directory containing a subdirectory named `Boltdir` as an embedded
project directory. Use this type of directory to embed Bolt management code into
another repo.

For example, you can store Bolt management code in the same repo as the
application that Bolt manages, without cluttering up the top level with multiple
files. This structure allows you to run Bolt from anywhere in the application's
directory structure.

An embedded Bolt directory looks like this:

```console
project/
├── Boltdir
│   ├── bolt-project.yaml
│   ├── inventory.yaml
│   ├── plans
│   │   ├── deploy.pp
│   │   └── diagnose.pp
│   └── tasks
│       ├── init.json
│       └── init.py
├── src #non Bolt source code for the project
└── tests #non Bolt tests for the project
```

As long as your `bolt-project.yaml` file contains a `name` field, Bolt loads
your local Bolt content from the top level of the `Boltdir`. Your `Boltdir` can
also contain modules. For more information, see [Modules](modules.md).

## How Bolt chooses a project directory

If Bolt can't find a directory based on `Boltdir` or `bolt-project.yaml`, it
uses the default: `~/.puppetlabs/bolt-project.yaml`.

Bolt uses the following methods, in order, to choose a Bolt directory.

1. **Environment variable:** You can specify a path to a project using the
   `BOLT_PROJECT` environment variable.
2. **Manually specified:** You can specify a directory path on the command line
   with `--project <DIRECTORY_PATH>`. There is not an equivalent configuration
   setting because the Bolt directory must be known in order to load
   configuration.
3. **Parent directory:** Bolt traverses parents of the current directory until
   it finds a directory containing a `Boltdir`, or
   `bolt-project.yaml`, or it reaches the root of the file system.
3. **Default project directory:** If no project directory is specified manually or found in
   a parent directory, Bolt uses `~/.puppetlabs/bolt/` as the project directory.

## World-writable project directories

On **Unix-like systems**, Bolt will not load a project from a world-writable
directory by default, as loading from a world-writable directory presents a
potential security risk. If you attempt to load a project from a
world-writable directory, Bolt will not load any content and will raise an
exception.

If you wish to override this behavior and force Bolt to load a project from a
world-writable directory, you can set the `BOLT_PROJECT` environment variable
to the project directory path.

For example, if you wanted to load a project named `my_project` from the
world-writable directory at `~/project/`, you would set the `BOLT_PROJECT`
environment variable as:

```bash
export BOLT_PROJECT='~/project/my_project'
```

> **Note:** Exported environment variables expire at the end of the current
> session. If you need a more permanent solution, add the `export` line to your
> `~/.bashrc` or the relevant profile for the shell you're using.

If you want to use a world-writable directory for a single Bolt execution, set the
environment variable before the Bolt command:

```bash
BOLT_PROJECT='~/project/my_project' bolt command run uptime -t target1
```

> **Note:** The `BOLT_PROJECT` environment variable takes precedence over the
> `--configfile` CLI option. 

## Common files and directories

The default paths for all Bolt configuration, code, and data are relative to the
module path.

|Directory|Description|
|---------|-----------|
|[`bolt.yaml`](bolt_configuration_reference.md)|Contains configuration options for Bolt. ⛔ **`bolt.yaml` is deprecated; use `bolt-project.yaml` instead.** |
|`hiera.yaml`|Contains the Hiera config to use for target-specific data when using `apply`.|
|[`inventory.yaml`](inventory_file_v2.md)|Contains a list of known targets and target specific data.|
|[`bolt-project.yaml`](bolt_configuration_reference.md#project_configuration_options)|Contains configuration options for Bolt and Bolt projects. For more information on Bolt projects, see [Bolt projects](./experimental_features.md#bolt-projects).|
|[`Puppetfile`](bolt_installing_modules.md#)|Specifies which modules to install for the project.|
|[`modules/`](bolt_installing_modules.md#)|The directory where modules from the `Puppetfile` are installed. In most cases, do not edit these modules locally.|
|[`site-modules/`](bolt_installing_modules.md)|Local modules that are edited and versioned with the Bolt directory.|
|`data/`|The standard path to store static Hiera data files.|
