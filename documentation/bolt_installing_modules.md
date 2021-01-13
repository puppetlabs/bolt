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
| `resolve` | Boolean. Whether to resolve the module's dependencies when installing modules. | |

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
| `name` | The name of the module. Bolt uses this name for the module in the Puppetfile, the directory that the module's contents are downloaded to, and as a namespace for the module's content. To avoid errors, make sure this name matches the name specified in the module's `metadata.json`. **Required if `resolve` is `false`.** | |
| `ref` | The git reference to checkout. Can be either a branch, commit, or tag. | ✓ |
| `resolve` | Boolean. Whether to resolve the module's dependencies when installing modules. | |

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

## Install Forge modules from an alternate Forge

You can configure Bolt to use a Forge other than the [Puppet
Forge](https://forge.puppet.com) when it installs Forge modules. To configure
Bolt to use an alternate Forge, set the `module-install` configuration option in
either your project configuration file, `bolt-project.yaml`, or the default
configuration file, `bolt-defaults.yaml`.

To use an alternate Forge for installing Forge modules, set the `baseurl` key
under the `forge` section of the `module-install` option:

```yaml
# bolt-project.yaml
module-install:
  forge:
    baseurl: https://forge.example.com
```

📖 **Related information**

- [bolt-project.yaml options](bolt_project_reference.md#module-install)
- [bolt-defaults.yaml options](bolt_defaults_reference.md#module-install)

## Install modules using a proxy

If your workstation cannot connect directly to the internet, you can configure
Bolt to use a proxy when it installs modules. To configure Bolt to use a proxy
when it installs modules, set the `module-install` configuration option in
either your project configuration file, `bolt-project.yaml`, or the default
configuration file, `bolt-defaults.yaml`.

To set a global proxy that is used for installing Forge and git modules, set
the `proxy` key under `module-install`:

```yaml
# bolt-project.yaml
module-install:
  proxy: https://proxy.com:8080
```

You can also set a proxy that is only used when installing Forge modules. To
set a proxy for installing Forge modules, set the `proxy` key under the `forge`
section of the `module-install` option:

```yaml
# bolt-project.yaml
module-install:
  forge:
    proxy: https://forge-proxy.com:8080
```

📖 **Related information**

- [bolt-project.yaml options](bolt_project_reference.md#module-install)
- [bolt-defaults.yaml options](bolt_defaults_reference.md#module-install)

## Skip dependency resolution for a module

Skipping dependency resolution for a module allows you to take advantage of
Bolt's module dependency resolution while still using modules that Bolt cannot
resolve dependencies for.

You might want to skip dependency resolution for a module if:

- The module has outdated or incorrect metadata.
- The module is a git module hosted in a repository other than a public GitHub
  repository.
- Bolt can't cleanly resolve the module's dependencies.

You can configure Bolt to skip dependency resolution for a module by setting the
`resolve` key for the module specification to `false`. This key is available for
both Forge and git modules.

When you install modules with Bolt, it only resolves module dependencies for
module specifications that do not set `resolve: false`. After resolving
dependencies, Bolt generates a Puppetfile with the resolved modules and
dependencies, as well as the modules it did not resolve dependencies for.

For example, if your project includes the `puppetlabs/ntp` Forge module and a
git module named `private_module` hosted in a private GitHub repository, you can
configure Bolt to skip dependency resolution for `private_module`:

```yaml
# bolt-project.yaml
name: myproject
modules:
  - puppetlabs/ntp
  - name: private_module
    git: git@github.com:puppetlabs/private_module
    ref: 1.0.0
    resolve: false
```

> **Note:** When setting `resolve: false` for a git module, you must include
> the `name` key.

When you install the project's modules, Bolt resolves dependencies for the
`puppetlabs/ntp` module, skips dependency resolution for `private_module`, and
generates a Puppetfile similar to this:

```ruby
# This Puppetfile is managed by Bolt. Do not edit.
# For more information, see https://pup.pt/bolt-modules

# The following directive installs modules to the managed moduledir.
moduledir '.modules'

mod 'puppetlabs/ntp', '8.5.0'
mod 'puppetlabs/stdlib', '6.5.0'
mod 'private_module',
  git: 'git@github.com:puppetlabs/private_module'
  ref: '1.0.0'
```

Because Bolt skips dependency resolution for module specifications that set
`resolve: false`, you'll need to include any dependencies for these modules
in your project configuration. For example, if `private_module` included
the following dependency in its `metadata.json` file:

```json
{
  . . .
  "dependencies": [
    {
      "name": "puppetlabs/docker",
      "version_requirement": ">= 3.0.0"
    }
  ]
}
```

You would add the dependency to your project configuration:

```yaml
# bolt-project.yaml
name: myproject
modules:
  - puppetlabs/ntp
  - name: private_module
    git: git@github.com:puppetlabs/private_module
    ref: 1.0.0
    resolve: false
  - name: puppetlabs/docker
    version_requirement: '>= 3.0.0'
```

## Manually manage a project's modules

If Bolt can't resolve your module dependencies, you can manage your project's
Puppetfile manually and use Bolt to install the modules listed in the Puppetfile
without resolving dependencies. The process for manually managing your modules
uses the new `module` subcommand, and replaces the now deprecated `puppetfile`
subcommand.

The most common scenario where Bolt can't resolve module dependencies is when
a project includes git modules that are in a repository other than a public
GitHub repository. If your project includes this type of module, you must
manually manage your project's Puppetfile.

To manually manage a project's Puppetfile and install modules without resolving
dependencies, follow these steps:

1. Set the `modules` configuration option in your `bolt-project.yaml` file to an
   empty array. For example:

   ```yaml
   # bolt-project.yaml
   name: myproject
   modules: []
   ```

1. Create a file named `Puppetfile` in your project directory and add the
   modules you want to install, including each module's dependencies, to
   the Puppetfile. For example:

   ```ruby
   # Modules from a private git repository
   mod 'private-module', git: 'https://github.com/bolt-user/private-module.git', ref: 'main'

   # Modules from an alternate Forge
   mod 'puppetlabs/apache', '5.7.0'
   mod 'puppetlabs/stdlib', '6.5.0'
   mod 'puppetlabs/concat', '6.3.0'
   mod 'puppetlabs/translate', '2.2.0'
   ```

1. Install the modules in the Puppetfile without resolving dependencies:

   _\*nix shell command_

   ```shell
   bolt module install --no-resolve
   ```

   _PowerShell cmdlet_

   ```powershell
   Install-BoltModule -NoResolve
   ```

Bolt installs modules in the Puppetfile to the `.modules/` directory in your
project directory. If you need to add or remove modules to the project, update
your Puppetfile and run the above command again.

## Migrate a project to use module management

If you created a Bolt project before module dependency management was
introduced, you can use Bolt's built-in migration tool to [update your
project](projects.md#migrate-a-bolt-project).

### Manual migration

In some cases, Bolt is unable to resolve module dependencies and manage your
project's modules for you. If Bolt can't resolve your module dependencies, you
can manage your project's Puppetfile manually and use Bolt to install the
modules listed in the Puppetfile without resolving dependencies. The most common
scenario where Bolt can't resolve module dependencies is when a project includes
git modules that are in a repository other than a public GitHub repository.

The module management feature makes changes to configuration files and changes
the directory where modules are installed. To migrate your project, do the
following:

1. Rename the `puppetfile` key in your `bolt-defaults.yaml` and
   `bolt-project.yaml` files to `module-install`. For example, the following
   file:

   ```yaml
   # bolt-project.yaml
   name: myproject
   puppetfile:
     forge:
       baseurl: https://myforge.example.com
     proxy: https://myproxy.example.com:8080
   ```

   Becomes:

   ```yaml
   # bolt-project.yaml
   name: myproject
   module-install:
     forge:
       baseurl: https://myforge.example.com
     proxy: https://myproxy.example.com:8080
   ```

1. Set the `modules` option in your `bolt-project.yaml` file to an
   empty array:

   ```yaml
   # bolt-project.yaml
   name: myproject
   modules: []
   ```

1. Delete all modules in the `modules/` directory of your project.

1. Copy all modules from the `site-modules/` and `site/` directories of your
   project to the `modules/` directory. If you have configured a `modulepath` for
   your project you do not need to complete this step.

1. If your project has a Puppetfile, install the modules in the Puppetfile
   without resolving dependencies:

   _\*nix shell command_

   ```shell
   bolt module install --no-resolve
   ```

   _PowerShell cmdlet_

   ```powershell
   Install-BoltModule -NoResolve
   ```

📖 **Related information**

- For a list of modules that are shipped with Bolt, see [Packaged modules](packaged_modules.md).
- For a list of plugins that Bolt maintains, see [Supported plugins](supported_plugins.md).
