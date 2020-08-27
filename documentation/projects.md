# Bolt projects

A Bolt project is a simple directory that serves as the launching point for
Bolt. You store your inventory file and configuration files in a project,
together with your Bolt content such as plans and tasks.

In addition to working with your local Bolt content, Bolt projects give you a
way to share that content with other users in your organization. You can create
orchestration that is specific to the infrastructure you're working with, and
then commit the project directory to version control for others to consume.

## Creating a Bolt project

Bolt identifies a directory as a Bolt project as long as a `bolt-project.yaml`
file exists at the root of the directory, and the `bolt-project.yaml` file
contains a `name` key.

To get started with a Bolt project:
1. Create a `bolt-project.yaml` file in the root of your Bolt project directory.
   This can be an existing directory, or a new one you make.
2. Name your project by adding a `name` key to the top of `bolt-project.yaml`.
   Project names can contain only lowercase letters, numbers, and underscores,
   and begin with a lowercase letter. For example:
   ```yaml
   name: myproject
   ```
3. Develop your Bolt plans and tasks in `plans` and `tasks` directories in the
   root of the project directory, next to `bolt-project.yaml`. Bolt loads tasks
   and plans from the `tasks` and `plans` directories and namespaces them to the
   project name.

Here is an example of a typical project with a task, a plan, and an inventory
file:

```console
.
├── bolt-project.yaml
├── inventory.yaml
├── plans
│   └── myplan.yaml
└── tasks
    ├── mytask.json
    └── mytask.py
```

## Configuring a project

Besides the `name` key, the `bolt-project.yaml` file holds options to configure
your Bolt project, as well as options to control how Bolt behaves when you run a
project.

For example, if you want to add a little flair to your Bolt output, use the
`rainbow` output format: 

```yaml
# bolt-project.yaml
name: myproject
format: rainbow
```

For a list of all the available project configuration options, see
[`bolt-project.yaml` options](bolt_project_reference.md).

### Limiting displayed plans and tasks

Projects allow you to limit which plans and
tasks a user can see when running `bolt plan show` or `bolt task show`. 

Limiting tasks and plans is useful for the following reasons:
- Bolt is bundled with several plans and tasks that might not be useful in your
  project. 
- You might have written a task or plan that is only used by another task or
  plan, and you don't want your users to run that task or plan directly.
- Displaying only specific content in the `show` commands makes it easier for
  your users to find what they're looking for.

To control what plans and tasks appear when your users run `bolt plan show` or
`bolt task show`, add `plans` and `tasks` keys to your `bolt-project.yaml` and
include an array of plan and task names. For example, to surface a
plan named `myproject::myplan`, and a task named `myproject::mytask`, you would
use the following `bolt-project.yaml` file:

```yaml
name: myproject
plans:
- myproject::myplan
tasks:
- myproject::mytask
```
If your user runs the `bolt plan show` command, they'll get similar output to
this:

```console
$ bolt plan show
myproject::myplan

MODULEPATH:
/PATH/TO/BOLT_PROJECT/site

Use `bolt plan show <plan-name>` to view details and parameters for a specific plan.
```

## Common files and directories in a project

The following are common files and directories found in a Bolt project.  

|Directory|Description|
|---------|-----------|
|[`bolt-project.yaml`](bolt_configuration_reference.md#project_configuration_options)|Contains configuration options for Bolt and  Bolt projects. This file must exist for Bolt to find any of the other files or directories in this list.|
|[`inventory.yaml`](inventory_file_v2.md)|Contains a list of known targets and target specific data.|
|[`plans/`](plans.md)|A directory for storing your plans.|
|[`tasks/`](tasks.md)|A directory for storing your tasks.|
|`files/`| A directory for storing content consumed by your tasks and plans, such as scripts.|
|[`Puppetfile`](bolt_installing_modules.md#)|Specifies which modules to install for the project.|
|[`modules/`](bolt_installing_modules.md#)|The directory where modules from the `Puppetfile` are installed. In most cases, do not edit these modules locally.|
|[`site-modules/`](bolt_installing_modules.md)|Local modules that are edited and versioned with the Bolt directory.|
|[`manifests`](applying_manifest_blocks.md)|A directory for storing your Puppet code files, known as _manifests_.|
|`hiera.yaml`|Contains the Hiera config to use for target-specific data when using `apply`.|
|`data/`|The standard path to store static Hiera data files.|
|`bolt-debug.log`|Contains debug log output for the most recent Bolt command.|
|[`bolt.yaml`](bolt_configuration_reference.md)|Contains configuration options for Bolt. ⛔ **`bolt.yaml` is deprecated; use `bolt-project.yaml` instead.** |

> **Remember:** A directory must have a `bolt-project.yaml` file before Bolt
> recognizes it as a Bolt project.

## How Bolt chooses a project directory

Most of the time, you run Bolt commands from within a Bolt project directory
that you've created. Running Bolt from inside your project allows Bolt to find
your inventory and other configuration files. 

However, Bolt always runs in the context of a project. If you don't run from
within your own Bolt project, or you don't specify a project, Bolt uses the
default project directory at `~/.puppetlabs/bolt/`.

Bolt uses the following methods, in order, to choose a Bolt directory.

1. **Environment variable:** You can specify a path to a project using the
   `BOLT_PROJECT` environment variable.
2. **Command-line specification:** You can specify a directory path on the
   command line with `--project <DIRECTORY_PATH>`. There is not an equivalent
   configuration setting because the Bolt directory must be known in order to
   load configuration.
3. **Parent directory:** Bolt traverses parents of the current directory until
   it finds one of the following:
   - A `bolt-project.yaml` file.
   - A directory named `Boltdir`.
4. **Default project directory:** If Bolt reaches the root of the file system
   without finding a `Boltdir` directory or `bolt-project.yaml` file, Bolt uses
   `~/.puppetlabs/bolt/` as the project directory.

For information on `Boltdir` directories, see [Embedded project directories](#embedded-project-directories).   

## Embedded project directories

If you need to embed your Bolt management code into another repo, you can use an
embedded project directory. For example, you can store Bolt management code in
the same repo as the application that Bolt manages. This prevents file clutter in the
top level of the repo and allows you to run Bolt from anywhere in the
application's directory structure.

To create an embedded project directory, create a subdirectory in your
application's repo and name it `Boltdir`. Bolt treats a directory containing a
subdirectory named `Boltdir` as an embedded project directory. 

The contents the `Boltdir` directory follows the same pattern as a local project
directory. As long as your `bolt-project.yaml` file contains a `name` field,
Bolt loads your local Bolt content from the top level of the `Boltdir`. Your
`Boltdir` can also contain modules. For more information, see
[Modules](modules.md).

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

In this example, you could run a Bolt command from the parent `project`
directory, and Bolt would still find your Bolt project.

> 🔩 **Tip:** You can use an existing [Puppet control
  repo](https://puppet.com/docs/pe/latest/control_repo.html) as a Bolt directory
  by adding a `bolt-project.yaml` file to it and configuring the `modulepath` to
  match the `modulepath` in `environment.conf`.

## Using modules in a Bolt project

Bolt projects make it easier for you to get started with Bolt without following
Puppet's module structure. However, if you're developing a custom module, you
can still use the Puppet module directory structure with Bolt. For more
information, see [Module structure](module_structure.md).

> **Note:** When you're naming your modules or Bolt project, keep in mind that
> projects take precedence over installed modules of the same name.

## World-writable project directories

On **Unix-like systems**, Bolt will not load a project from a world-writable
directory by default, as loading from a world-writable directory presents a
potential security risk. If you attempt to load a project from a
world-writable directory, Bolt does not load any content and raises an
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

📖 **Related information**

- [Tasks](tasks.md)
- [Plans](plans.md)
- [Inventory files](inventory_file_v2.md)
