# Experimental features

Most larger bolt features are released initially in an experimental or unstable state. This allows the bolt team to gather feedback from real users quickly while iterating on new functionality. Almost all experimental features are eventually stabilized in future bolt releases. While a feature is experimental it's API may change requiring the user to update their code or configuration. The bolt team attempts to make these changes painless and provide useful warnings around breaking behavior where possible. 
Experimental features are subject to possible breaking changes between minor Bolt
releases.

## Bolt projects

This feature was introduced in [Bolt 
2.8.0](https://github.com/puppetlabs/bolt/blob/master/CHANGELOG.md#bolt-280-2020-05-05)

Bolt project directories have been around for a while in Bolt, but this release
signals a shift in the direction we're taking with them. We see Bolt projects as
a way for you to quickly create orchestration that is specific to the
infrastructure you're working with, and then commit the project directory to git
and share it with other users in your org. 

There are some barriers around quickly creating and sharing Bolt content that
is specific to your infrastructure. Bolt's current project structure
is closely tied to Puppet modules - you put your tasks and plans in child
directories of `site-modules` and Bolt loads that content as a module. This is
fine if your aim is to share your content on the forge or use it
programmatically, but in cases where you're looking to share orchestration that
is specific to your infrastructure, it's not always necessary, and can be cumbersome to get going quickly. 

We also needed a way for content authors to whitelist the plans and tasks that
they've created, so that when they share the content with other users, those
users can run `bolt plan show` or `bolt task show` from the project directory
and be presented with a list of only the content they need to see. 

### Using Bolt projects

Before your begin, make sure you've [updated Bolt to version 2.8.0 or
higher](./bolt_installing.md).

> **Remember:** This feature is experimental and is subject to possible breaking
> changes between minor Bolt releases.

To get started with a Bolt project:
1. Create a `project.yaml` file in the root directory of your Bolt project. 
2. Develop your Bolt plans and tasks in `plans` and `tasks` directories in the
   respectively in the root project directory.

If `project.yaml` exists at the root of a project directory, Bolt loads the
project as a module. Bolt loads tasks and plans from the `tasks` and `plans`
directories and namespaces them to the project name.

Here is an example of a project using a simplified directory structure:
```console
.
├── bolt.yaml
├── inventory.yaml
├── plans
│   └── myplan.yaml
├── project.yaml
└── tasks
    └── mytask.yaml
```
### Naming your project

If you want to set a name for your project that is different from the name of
the Bolt project directory, add a `name` key to `project.yaml` with the project
name. 

For example:
  ```yaml
  name: myproject
  ```

Project names must match the expression: `[a-z][a-z0-9_]*`. In other words, they
can contain only lowercase letters, numbers, and underscores, and begin with a 
lowercase letter.

> **Note:** Projects take precedence over installed modules of the same name. 
To see a list of other options available in `project.yaml`, see [Bolt
configuration options](./bolt_configuration_reference.md#project-configuration-options).

### Whitelisting plans and tasks

To control what tasks and plans appear when your users run `bolt plan
show` or `bolt task show`, add `tasks` and `plans`
keys to your `project.yaml` and include an array of task and plan names. 

For example, if you wanted to surface a plan named `myproject::myplan`, and a
task named `myproject::mytask`, you would use the following `project.yaml` file:

```yaml
name: myproject
plans:
- myproject::myplan
tasks:
- myproject::mytask
```
If your user runs the `bolt plan show` command, they'll get similar output to this:

```console
$ bolt plan show
myproject::myplan

MODULEPATH:
/PATH/TO/BOLT_PROJECT/site

Use `bolt plan show <plan-name>` to view details and parameters for a specific plan.
```
