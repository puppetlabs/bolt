# 🧪 Bolt projects

🧪 **Experimental:** Bolt projects are experimental and may change in future
versions of Bolt. Make sure you've updated to the most recent version of Bolt to
take full advantage of this feature.

One of the first things you'll do when you start using Bolt is create a Bolt
project. A Bolt project is a simple directory that serves as the launching point
for Bolt. You run Bolt from your project directory, and the directory houses
your Bolt configuration files and your Bolt content, such as plans and tasks.

In addition to working with your local Bolt content, Bolt projects give you a
way to share that content with other users in your organization. You can create
orchestration that is specific to the infrastructure you're working with, and
then commit the project directory to version control for others to consume.

Here is an example of a typical project with a task, a plan, and an inventory file:

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

Bolt projects are experimental. Make sure you've [updated to the latest version
of Bolt](./bolt_installing.md) to get the most out of this feature.

📖 **Related information**

- [Tasks](tasks.md)
- [Plans](plans.md)
- [Inventory files](inventory_file_v2.md)

## Creating a Bolt project

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
   root of the project directory, next to `bolt-project.yaml`.

Bolt treats a directory as a Bolt project as long as a `bolt-project.yaml` file
exists at the root of the directory and contains a `name` key. Bolt loads tasks
and plans from the `tasks` and `plans` directories and namespaces them to the
project name.

## Configuring a project

The `bolt-project.yaml` file holds options to configure your Bolt project, as
well as options to control how Bolt behaves when you run a project.

For example, if you wanted Bolt to load a custom module path, you could use the
following in your `bolt-project.yaml`:

```yaml
# bolt-project.yaml
name: myproject
modulepath: ['modules','site-modules','/home/user/mymodules']
```

For a list of all the available configuration options in `bolt-project.yaml`,
see [`bolt-project.yaml` options](bolt_project_reference.md).

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
include an array of plan and task names. For example, if you wanted to surface a
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

## Using modules in a Bolt project

Bolt projects make it easier for you to get started using Bolt without following
Puppet's module structure, but if you're developing a custom module,
you can still use module directory structure with Bolt. For more information,
see [Module structure](module_structure.md).

> **Note:** When you're naming your modules or Bolt project, keep in mind that
> projects take precedence over installed modules of the same name.
