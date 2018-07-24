
# Installing modules with Bolt

Bolt uses a Puppetfile to specify which modules to install. The Puppetfile
should be in the Boltdir, which can either be a project-specific directory
named `Boltdir` at the root of your project, or a global directory in
`$HOME/.puppetlabs/bolt`.

The Puppetfile contains a list of modules and versions to install. If the
modules have dependencies on other modules, those dependencies will need to be
listed in the Puppetfile as well.

By default, modules will be downloaded from the Puppet Forge. Modules can be
installed from git repositories instead by setting the `git` and `ref`
properties.
```
mod 'puppetlabs/package', '0.2.0'
mod 'puppetlabs/service', '0.3.1'
mod 'puppetlabs/puppetlabs-facter_task', git: 'git@github.com:puppetlabs/puppetlabs-facter_task.git', ref: 'master'
mod 'myteam/app_foo', local: true
```

The modules from the Puppetfile can be installed with the `bolt puppetfile
install` command. By default, this will install them to the `modules`
subdirectory inside the Boltdir. This location can be overridden with the
`modulepath` setting in the Bolt config file.

If the Boltdir contains any modules which aren't listed in the Puppetfile, they
will be deleted. If you want to commit modules containing tasks/plans directly
to a project, add the module to the Puppetfile with `local: true`.

For more details about specifying modules in a Puppetfile, see [the complete
Puppetfile documentation](https://puppet.com/docs/pe/latest/puppetfile.html).
