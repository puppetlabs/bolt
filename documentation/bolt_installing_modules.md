# Installing modules

When you use the Bolt command line to install a module, Bolt manages your
dependencies for you. 

You can use the command line to:
- Create a project with pre-installed modules.
- Add a Puppet Forge module to your existing Bolt project.
- Install the modules associated with a Bolt project. This is useful if you've
  downloaded a project from source control and want to install its dependencies.
- Update your project's modules.

If you need to install a module from a GitHub repository or an alternate Forge,
or you need to use a Forge proxy, you can manually configure your Bolt modules
in your Bolt project configuration file (`bolt-project.yaml`).

## Create a Bolt project with pre-installed modules

If you want to get started with a new Bolt project and you need specific modules
from the Puppet Forge, you can install the modules and their dependencies using
the Bolt command line.

When you create a project with the `modules` command-line option and a
comma-separated list of Forge modules, Bolt installs the latest versions of each
module and resolves and installs all dependencies required by those modules. For
example, to turn the current directory into a project named `example_project`
with the `puppetlabs/apache` and `puppetlabs/mysql` modules installed, use the following command:

_\*nix shell command_

```shell
bolt project init example_project --modules puppetlabs-apache,puppetlabs-mysql
```

_PowerShell cmdlet_

```powershell
New-BoltProject -Name example_project -Modules puppetlabs-apache,puppetlabs-mysql
```

The project's Puppetfile lists the `puppetlabs/apache` and `puppetlabs/mysql`
modules and all of their dependencies:

```puppet
# example_project/Puppetfile
mod 'puppetlabs-apache', '5.5.0'
mod 'puppetlabs-mysql', '10.6.0'
mod 'puppetlabs-stdlib', '6.3.0'
mod 'puppetlabs-concat', '6.2.0'
mod 'puppetlabs-translate', '2.2.0'
mod 'puppetlabs-resource_api', '1.1.0'
mod 'puppetlabs-puppetserver_gem', '1.1.1'
```

## Install a module to an existing project

Before you use the Bolt command line to install a module to an existing project,
make sure the project is configured to use dependency management. If your
`bolt-project.yaml` file contains a `modules` key, your project is set up for
dependency management. If your `bolt-project.yaml` file does not contain a
`modules` key, [migrate your project](projects.md#migrate-a-bolt-project).

### Add a Forge module and its dependencies to an existing project

To add a single Puppet Forge module and its dependencies to your Bolt project,
use the `bolt module add` *nix shell command or the `Add-BoltModule` Powershell
cmdlet. For example, to add the `puppetlabs/apt` module:

*\*nix shell command*
```shell
bolt module add puppetlabs/apt
```

*Powershell cmdlet*
```shell
Add-BoltModule -Module puppetlabs/apt
```

Bolt adds a specification to your project configuration file, resolves
dependencies, updates your project's Puppetfile, and installs the modules to the
project's `.modules` directory.

> **Note:** This command only works with Forge modules. To add a git module,
> [manually specify the module in your project configuration
> file](#git-modules).

When Bolt adds a new module to the project and resolves its dependencies, it
attempts to keep all installed modules on the same versions. If Bolt encounters
a version conflict, it may update installed modules to newer versions.

📖 **Related information** 
- If you receive an error telling you to "update your project configuration to
  manage module dependencies", see [migrate a Bolt
  project](projects.md#migrate-a-bolt-project).

### Install the modules associated with a Bolt project

If you've just downloaded a Bolt project from source control and want to install
the modules associated with it, use the following command:

*\*nix shell command*
```shell
bolt module install
```

*Powershell cmdlet*
```shell
Install-BoltModule
```

Bolt loads your `bolt-project.yaml` file, resolves dependencies for all of the
declared modules, writes a Puppetfile to your project that includes
specifications for the resolved modules, and installs the modules to the
project's `.modules` directory.

#### Forcibly install modules

When you add a module to a project, or install a project's modules, Bolt
compares the module specifications in the project configuration file to the
modules in the Puppetfile to check if an existing Puppetfile is managed by Bolt.
If the Puppetfile is missing any module specifications, Bolt assumes the
Puppetfile is not managed by Bolt and raises an error like this:

```shell
Puppetfile at /myproject/Puppetfile does not include modules that
satisfy the following specifications:

- name: puppetlabs-ruby-task-helper

This may not be a Puppetfile managed by Bolt. To forcibly overwrite the
Puppetfile, run 'bolt module install --force'.
```

This error usually only occurs if you've manually modified your
`bolt-project.yaml` or `Puppetfile`. To resolve the conflict and install the
modules declared in `bolt-project.yaml`, run the following command:

*\*nix shell command*
```shell
bolt module install --force 
```

*Powershell cmdlet*
```shell
Install-BoltModule -Force
```

## Update a project's modules

To update the modules in your project, run:

*\*nix shell command*
```shell
bolt module install --force
```

*Powershell cmdlet*
```shell
Install-BoltModule -Force
```

Bolt updates your modules to the latest available versions and attempts to
resolve all of the modules in the project configuration file to ensure that
there are no version conflicts between modules and their dependencies.

## Manually specify modules in a Bolt project

In most cases, you can use the Bolt command line to install a new module.
However, there are times when you might want to manually specify a module
instead of using the Bolt command line. For example, you might want to add a git
module, which is not supported through the command line, or you might want to
add a large number of modules to your project at once and you don't want to
string together multiple commands.

To manually specify a module in a Bolt project, add a specification to the
project configuration file `bolt-project.yaml`. Specifications are listed under
the `modules` key, and include specific keys depending on the type of module
specified.

### Forge modules

To specify a Forge module, use the following keys in the specification:

| Key | Description | Required |
| --- | --- | :-: |
| `name` | The full name of the module. Can be either `<OWNER>-<NAME>` or `<OWNER>/<NAME>`. | ✓ |
| `version_requirement` | The version requirement that the module must satisfy. Can be either a specific semantic version (`1.0.0`), a version range (`>= 1.0.0 < 3.0.0`), or version shorthand (`1.x`).  |

After you've made changes to the module specification, [update your
modules](#update-a-projects-modules).

The following example specifies the `puppetlabs/apache` Forge module with a
shorthand version requirement:

```yaml
modules:
  - name: puppetlabs/apache
    version_requirement: '5.x'
```

If you do not need to add a version requirement to a specification, you can
specify a Forge module using just the name of the module without using the
`name` key. For example:

```yaml
modules:
  - puppetlabs/apache
```

### Git modules

To specify a git module, use the following keys in the specification:

| Key | Description | Required |
| --- | --- | :-: |
| `git` | The URI to the GitHub repository. URI must begin with either `https://github.com`or `git@github.com`. | ✓ |
| `ref` | The git reference to checkout. Can be either a branch, commit, or tag. | ✓ |

After you've made changes to the module specification, [update your
modules](#update-a-projects-modules).

The following example specifies the `puppetlabs/puppetlabs-puppetdb` git module
with a specific tag:

```yaml
modules:
  - git: https://github.com/puppetlabs/puppetlabs-puppetdb
    ref: '7.0.0'
```

Bolt only supports installing git modules from GitHub.

## Pin a module version

If you need to pin a module in your Bolt project to a specific version, you can
add a version requirement to the module in your `bolt-project.yaml` and run the
`install` command with the `force` option.

Follow these steps to pin a module version:
1. Find the module under the `modules` key in your `bolt-project.yaml` file.
1. Add a `version_requirement` key that specifies the version requirements for
   the module. For example, the following `bolt-project.yaml` file sets the
   version requirement for the `puppetlabs/apache` module to greater than or equal to
   4.0.0, but less than 6.0.0:
   ```yaml
   # bolt-project.yaml
   ...
   modules:
   - name: puppetlabs/apache
     version_requirement: '>= 4.0.0 < 6.0.0'
   ```
1. Run the following command. The `force` option is required because you've made
   a change to your `bolt-project.yaml` file, and it no longer matches the
   Puppetfile.

   *\*nix shell command*
   ```shell
   bolt module install --force 
   ```

   *Powershell cmdlet*
   ```shell
   Install-BoltModule -Force
   ```

When you run the install command with the `force` option, Bolt attempts to
resolve all of the modules in the project configuration file to ensure that
there are no version conflicts between modules and their dependencies. Bolt
fails with an error message if it cannot resolve a dependency due to a version
requirement. 

> 🔩 **Tip**: For information on how to specify module versions, see the Puppet
> documentation on [Specifying
> versions](https://puppet.com/docs/puppet/latest/modules_metadata.html#specifying-versions).

## ⛔ Manage modules with a Puppetfile

⛔ **DEPRECATED:** This method of installing and managing modules is deprecated.
Use the workflows outlined above and avoid editing your Puppetfile.

If you want to install a module to an existing project, use a Puppetfile. This
method does not automatically resolve module dependencies. If the module you're
installing requires other modules, make sure you add the required modules to
your Puppetfile together with the module you're installing.

> **Before you begin**
>
> - In your Bolt project directory, create a file named `Puppetfile`. 
> - Add any modules stored locally in `modules/` to the list. For example, 
>   ```puppet
>     mod 'my_awesome_module', local: true
>   ```
>
>   **Bolt deletes any content in `modules/` that is not listed in your
>   Puppetfile.** If you want to keep the content, but you don't want to manage
>   it with the Puppetfile, move the content to a `site-modules` directory in
>   your project.

To install a module:
   1.  Open Puppetfile in a text editor and add the modules and versions that
       you want to install. If the modules have dependencies, list those as
       well. For example:
       ```puppet
       # Modules from the Puppet Forge.
       mod 'puppetlabs-apache', '4.1.0'
       mod 'puppetlabs-postgresql', '5.12.0'
       mod 'puppetlabs-puppet_conf', '0.3.0'

       # Modules from a Git repository.
       mod 'puppetlabs-haproxy', git: 'https://github.com/puppetlabs/puppetlabs-haproxy.git', ref: 'master'
       ```   
   1. Run the `bolt puppetfile install` command. Bolt installs modules to the
      first directory in the `modulepath` setting. By default, this is the
      `modules/` subdirectory inside the Bolt project directory. To override
      this location, update the `modulepath` setting in your [project
      configuration file](bolt_project_reference.md).
