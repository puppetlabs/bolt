# Modules overview

Modules are directories that contain Puppet code designed to solve a specific
use case or manage an application. Many of the modules on the Puppet Forge
include helpful plans and tasks that you can install with Bolt and use in your
workflows. But even if a module doesn't contain a task or a plan, you can
still use Bolt to apply code from that module to your targets.

Modules also allow you to share your own custom Bolt tasks and plans on the
Forge or use your Bolt content programmatically.

📖 **Related information**

- [Applying Puppet code](applying_manifest_blocks.md)
- [Puppet Forge](https://forge.puppet.com/)

## Dependency management

Many modules depend on other modules to work properly. When you install a module
using the Bolt command-line interface (CLI), Bolt automatically manages those
dependencies for you.

First, Bolt adds the module to your project configuration file
(`bolt-project.yaml`) under a `modules` key. For example, if you created a
project and added the `mysql` and `apache` modules, your `bolt-project.yaml`
file would contain the following section:

```yaml
# bolt-project.yaml
...
modules:
  - puppetlabs/apache
  - puppetlabs/mysql
```

Next, Bolt resolves the modules and their dependencies and generates a
Puppetfile. Avoid editing your Puppetfile directly. The Puppetfile for the above
project would look like this:

```
# Puppetfile
...

# The following directive installs modules to the managed moduledir.
moduledir '.modules'

mod 'puppetlabs/apache', '5.6.0'
mod 'puppetlabs/puppetserver_gem', '1.1.1'
mod 'puppetlabs/resource_api', '1.1.0'
mod 'puppetlabs/translate', '2.2.0'
mod 'puppetlabs/stdlib', '6.5.0'
mod 'puppetlabs/mysql', '10.8.0'
mod 'puppetlabs/concat', '6.2.0'

```

Finally, Bolt installs the modules and dependencies to the Bolt-managed module
directory (moduledir) in your Bolt project directory (`.modules`):

```shell
.modules/
├── apache/
├── concat/
├── mysql/
├── puppetserver_gem/
├── resource_api/
├── stdlib/
└── translate/
```

📖 **Related information**

- [Installing modules](bolt_installing_modules.md)
- [Bolt projects](projects.md)

## Modulepath

The list of directories where Bolt looks for content is called the modulepath.
Bolt always loads content from:
- The current Bolt project.
- Any modules in the configurable modules directory. By default this is
  `modules/`.
- The Bolt-managed moduledir (`.modules`).
- Any modules that come bundled with Bolt.

If you'd like to modify or add a directory to Bolt's modulepath, add the path to
the directory to a `modulepath` key in your `bolt-project.yaml` file. The
`modulepath` key accepts an array of directories. For example, if you wanted to
load modules from a directory at `../my-modules/modules/` in addition to the
`modules` directory:

```yaml
# bolt-project.yaml
...
  modulepath: 
  - modules
  - ../my-modules/modules/
```

If you add a `modulepath` key and omit `modules`, Bolt will not load content
from the `modules` directory.

You can see a list of directories and modules Bolt is
loading from the current modulepath using the following command:

_*nix shell command_
```
bolt module show
```

_PowerShell cmdlet_
```
Get-BoltModule
```

## Compatibility with Bolt versions

Bolt 2.30.0 introduced module dependency management. The changes introduced by
this feature affect:
- Existing Bolt projects that were created before the dependency changes came
  into effect. For information on how to migrate your Bolt project to use
  dependency management, see [Migrate a Bolt
  project](projects.md#migrate-a-bolt-project).
- Your Puppet Enterprise installation (if you're using the dependency management
  feature).

### Puppet Enterprise (PE) compatibility

Bolt sets the moduledir in the Puppetfile to `.modules/` which is not on the
modulepath in versions of Bolt before 2.30.0. If you're using Bolt's dependency
management feature in an environment in Puppet Enterprise, you must specify
`.modules` on the modulepath in your
[environment.conf](https://puppet.com/docs/puppet/latest/config_file_environment.html#example).

For example:

```
# /etc/puppetlabs/code/environments/test/environment.conf

modulepath = site:dist:modules:$basemodulepath:.modules
```

You can learn more about the module changes introduced in Bolt 2.23.0 in the
[September 2020 developer update](./developer_updates.md#september-2020).
