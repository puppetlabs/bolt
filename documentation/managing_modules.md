# 🧪 Managing modules in Bolt projects

Bolt version 2.30.0 introduced improvements to Bolt projects that make it easier
to manage your project's modules. This includes the addition of the `bolt module
add` and `bolt module install` commands, as well as changes to the `bolt project
migrate` command. These changes are experimental. To find out more about why we
made these changes, see our [September 2020 developer
update](developer_updates.md#september-2020).

## What's changed?

- **Managed module installation directory:** Bolt now installs modules it
  manages into the `.modules/` directory instead of `modules/`. Avoid committing
  `.modules/` to source control. Your users can download your Bolt project and
  use the `bolt module install` command to download the required modules from
  the Forge.
- **Non-managed module directory:** Bolt no longer uses the `site-modules/`
  directory. Store any modules that you don't want Bolt to manage in the
  `modules/` directory. This includes custom modules and non-Forge modules.
- **Module configuration:** Your `bolt-project.yaml` file contains a `modules`
  key that lists the direct module dependencies of your Bolt project. Unless you
  need to pin a module to a specific version, avoid editing the `modules` list
  directly. Instead, use the `bolt module add` command.
- **Puppetfile:** The Puppet file is now a lock file. Bolt generates a
  Puppetfile each time you modify your modules with a Bolt command. Do not edit
  the Puppetfile directly. Instead, use Bolt commands to manage your modules,
  and rely on Bolt to manage the Puppetfile. You can compare a Puppetfile to a
  [Gemfile.lock](https://bundler.io/rationale.html#checking-your-code-into-version-control)
  file in Ruby, or a
  [yarn.lock](https://classic.yarnpkg.com/en/docs/yarn-lock/) file in Yarn.
- **modulepath:** The new modulepath is `['modules']` and Bolt always appends
  `.modules` to the modulepath.

## How it works

A Bolt project lists its module dependencies in the `bolt-project.yaml` file
under the `modules` key. For example, a Bolt project that uses the `mysql` and
`apache` modules might look like this:

```yaml
modules:
- puppetlabs/apache
- puppetlabs/mysql
```

When you use Bolt to install a project's modules, it loads the information from
the `modules` key in your `bolt-project.yaml`, resolves the modules and their
dependencies, generates a Puppetfile listing all of the modules to install, and
then installs the modules.

If your project needs another module, you can use the `bolt module add` command to add the module to your
project configuration, generate a new Puppetfile that includes the new module
and its dependencies, and install the modules.

## Opting in

**Before you begin:** To opt in, you need a Bolt project. You can create a new
project using the steps described in [Installing
modules](bolt_installing_modules.md#create-a-new-bolt-project-and-install-a-list-of-modules-with-dependencies),
or use an existing Bolt project. Migrating a project makes irreversible changes to the project's
configuration and inventory files. **Before you migrate, make sure the project
has a backup or uses a version control system.**

Use the following command to migrate a Bolt project:

*\*nix shell command*
```shell
bolt project migrate
```

*Powershell cmdlet*
```shell
Update-BoltProject
```

Bolt reads your Puppetfile and prompts you to choose which modules are direct
dependencies of your project. Only select a module as a direct dependency if
your project uses content from that module.

After you've selected your project's direct dependencies, Bolt adds those
modules to your `bolt-project.yaml` file and pins them to their current
versions, installs those modules and their dependencies into a `.modules`
directory, and generates a Puppetfile. 

If you don't want your modules pinned to a specific version, edit out the
`version_requirement` fields for each module in your `bolt-project.yaml` file
and run:

*\*nix shell command*
```shell
bolt module install --force 
```

*Powershell cmdlet*
```shell
Install-BoltModule -Force
```

## Install modules in a Bolt project

After you've opted in, you can use the `bolt module add` and `bolt module
install` commands to manage your Forge modules. 

> **Note:** Bolt only supports managing modules from the public Puppet
> Forge. Git modules and private Forge modules are not supported.

### Add a Forge module and its dependencies to an existing project

To add a single module and its dependencies to your Bolt project, use the `bolt
module add` command. For example, to add the puppetlabs/apt module:

*\*nix shell command*
```shell
bolt module add puppetlabs/apt
```

*Powershell cmdlet*
```shell
Add-BoltModule -Module puppetlabs/apt
```

Bolt adds a declaration to your project configuration file, resolves
dependencies, updates your project's Puppetfile, and installs the modules to the
project's `.modules` directory.

When Bolt adds a new module to the project and resolves its dependencies, it
attempts to keep all installed modules on the same versions. If Bolt is unable
to do this due to a version conflict, it may update installed modules to newer
versions.

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
compares the module declarations in the project configuration file to the
modules in the Puppetfile to check if an existing Puppetfile is managed by Bolt.
If the Puppetfile is missing any module declarations, Bolt assumes the
Puppetfile is not managed by Bolt and raises an error like this:

```shell
Puppetfile /myproject/Puppetfile is missing specifications for the following
module declarations:

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

## Update your project's modules

To update the modules in your project, run:

*\*nix shell command*
```shell
bolt module install
```

*Powershell cmdlet*
```shell
Install-BoltModule
```

Bolt updates your modules to the latest available versions and attempts to
resolve all of the modules in the project configuration file to ensure that
there are no version conflicts between modules and their dependencies.

## Pin a module version

If you need to pin a module in your Bolt project to a specific version, you can
add a version requirement to the module in your `bolt-project.yaml` and run the
`install` command with the `force` option.

Follow these steps to pin a module version:
1. Find the module under the `modules` key in your `bolt-project.yaml` file.
2. Add a `version_requirement` key that specifies the version requirements for
   the module. For example, the following `bolt-project.yaml` file sets the
   version requirement for the `apache` module to greater than or equal to
   4.0.0, but less than 6.0.0:
   ```yaml
   # bolt-project.yaml
   ...
   modules:
   - name: puppetlabs/apache
     version_requirement: '>= 4.0.0 < 6.0.0'
   ```
3. Run the following command. The `force` option is required because
   you've made a change to your `bolt-project.yaml` file, and it no longer
   matches the Puppetfile.
   
   *\*nix shell command*
   ```shell
   bolt module install --force 
   ```

   *Powershell cmdlet*
   ```shell
   Install-BoltModule -Force
   ```

When you run the install command with the `force` option, Bolt attempts to resolve all of the
modules in the project configuration file to ensure that there are no version
conflicts between modules and their dependencies. Bolt fails with an error
message if it cannot resolve a dependency due to a version requirement. 

> 🔩 **Tip**: For information on how to specify module versions, see the Puppet
> documentation on [Specifying
> versions](https://puppet.com/docs/puppet/latest/modules_metadata.html#specifying-versions).

## Compatibility with Bolt versions

The new module management style is incompatible with older Bolt versions, since it sets the
moduledir in the Puppetfile to `.modules/` which is not on the modulepath in versions < 2.30.0. If
you're using the new module management system in an environment in Puppet Enterprise, you need to
specify `.modules` on the modulepath in your [environment.conf](https://puppet.com/docs/puppet/latest/config_file_environment.html#example), like so:

```
# /etc/puppetlabs/code/environments/test/environment.conf

modulepath = site:dist:modules:$basemodulepath:.modules
```

## Examples

### Migrate an existing Bolt project

Given a project named `myproject` with a custom module named `mymodule` in your `site-modules` directory, and the following Puppetfile:

```puppet
mod "puppetlabs-apache", "5.5.0"
mod "puppetlabs-apt", "7.6.0"
mod "puppetlabs-mysql", "10.7.1"
mod "puppetlabs-stdlib", "6.4.0"
mod "puppetlabs-concat", "6.2.0"
mod "puppetlabs-translate", "2.2.0"
mod "puppetlabs-resource_api", "1.1.0"
mod "puppetlabs-puppetserver_gem", "1.1.1"
```

If you ran the `migrate` command, and selected the `apache`, `apt`, and `mysql` modules as direct dependencies of your Bolt project, Bolt would do the following:
- Update your `bolt-project.yaml` file to add the `modules` key, together with the `apache`, `apt`, and `mysql` modules:
  ```yaml
  ---
  name: myproject
  modules:
  - name: puppetlabs-apache
  version_requirement: "=5.5.0"
  - name: puppetlabs-apt
  version_requirement: "=7.6.0"
  - name: puppetlabs-mysql
  version_requirement: "=10.7.1"
  ```
- Resolve your dependencies and generate a new Puppetfile:
  ```puppet
  # This Puppetfile is managed by Bolt. Do not edit.
  mod "puppetlabs-apache", "5.5.0"
  mod "puppetlabs-apt", "7.6.0"
  mod "puppetlabs-mysql", "10.7.1"
  mod "puppetlabs-stdlib", "6.4.0"
  mod "puppetlabs-concat", "6.2.0"
  mod "puppetlabs-translate", "2.2.0"
  mod "puppetlabs-resource_api", "1.1.0"
  mod "puppetlabs-puppetserver_gem", "1.1.1"
  ```
- Install the modules from the Puppetfile into the `.modules` directory.
- Remove the old managed modules from the `modules/` directory.
- Move `mymodule` from `site-modules/` to `modules/`.

### Install a module with `add`

If you had a new project named `myproject` and installed `apache` with the `add`
command above, the `modules` key in your `bolt-project.yaml` file would look
something like this:

```yaml
name: example_project
modules:
- name: puppetlabs-apache
```

The project's Puppetfile lists the `apache` module and all of its dependencies:

```puppet
# This Puppetfile is managed by Bolt. Do not edit.
mod "puppetlabs-apache", "5.5.0"
mod "puppetlabs-stdlib", "6.4.0"
mod "puppetlabs-concat", "6.2.0"
mod "puppetlabs-translate", "2.2.0"
```

And the `.modules` directory contains all of the installed modules:

```shell
$ ls .modules
apache    concat    stdlib    translate
```

📖 **Related information**

- [Bolt projects](projects.md)
