# Bolt documentation

This directory contains the markdown files used to generate the official
[Bolt Documentation](https://puppet.com/docs/bolt/latest/bolt.html). To make
changes to most of Bolt's documentation, you can edit the corresponding
markdown file directly. However, some of Bolt's documentation is generated
as part of the release process and requires edits to either Bolt's source
code or to the template used to generate the documentation.

## Generated documentation

Several pages of Bolt's documentation are generated as part of Bolt's release
process and do not have markdown files in this directory. Each of the generated
pages has an associated Embedded Ruby template located in the
[templates](./templates) directory as well as a [rake task](../rakelib/docs.rake)
that is used to generate the documentation. Each rake task retrieves data from
Bolt's source code and sends it to a rendering engine that generates a markdown
file from the template. The generated markdown file is saved to the
`documentation` directory.

You can generate all documentation using the following rake task:

```shell
$ bundle exec rake docs:all
```

Here are each of the documenation pages that are generated, the files
that you may need to modify to make changes to the generated documentation,
and the rake task used to generate the documentation.

### *nix shell commands

**Documentation page** 
- https://puppet.com/docs/bolt/latest/bolt_command_reference.html

**Template file**
- [`bolt_command_reference.md.erb`](./templates/bolt_command_reference.md.erb)

**Relevant source code**
- [`bolt_option_parser.rb`](../lib/bolt/bolt_option_parser.rb)

To generate this documentation, run:

```shell
$ bundle exec rake docs:command_reference
```

### PowerShell cmdlets

**Documentation page** 
- https://puppet.com/docs/bolt/latest/bolt_cmdlet_reference.html

**Template file**
- [`bolt_cmdlet_reference.md.erb`](./templates/bolt_cmdlet_reference.md.erb)

**Relevant source code**
- [`bolt_option_parser.rb`](../lib/bolt/bolt_option_parser.rb)
- [`pwsh.rb`](../rakelib/lib/pwsh.rb)

To generate this documentation, run:

```shell
$ bundle exec rake docs:cmdlet_reference
```

### Bolt functions

**Documentation page**
- https://puppet.com/docs/bolt/latest/plan_functions.html

**Template file**
- [`reference.md.erb`](./templates/reference.md.erb)

**Relevant source code**

The rake task for this page uses `puppet-strings` to generate documentation
from comments in a function's source code. Bolt ships with several core modules
that are located in the `bolt-modules` directory. To modify the documentation
for a plan function, locate its file and modify the comments.

- [`boltlib`](../bolt-modules/boltlib/lib/puppet/functions)
- [`ctrl`](../bolt-modules/boltlib/lib/puppet/functions)
- [`file`](../bolt-modules/boltlib/lib/puppet/functions)
- [`out`](../bolt-modules/boltlib/lib/puppet/functions)
- [`prompt`](../bolt-modules/boltlib/lib/puppet/functions)
- [`system`](../bolt-modules/boltlib/lib/puppet/functions)

To generate this documentation, run:

```shell
$ bundle exec rake docs:function_reference
```

### ⛔ `bolt.yaml` options

⛔ `bolt.yaml` is deprecated and will be removed in a future version of Bolt.

**Documentation page**
- https://puppet.com/docs/bolt/latest/bolt_configuration_reference.html

**Template file**
- [`bolt_configuration_reference.md.erb`](./templates/bolt_configuration_reference.md.erb)

**Relevant source code**
- [`config/options.rb`](../lib/bolt/config/options.rb)

To generate this documentation, run:

```shell
$ bundle exec rake docs:config_reference
```

### `bolt-defaults.yaml` options

**Documentation page**
- https://puppet.com/docs/bolt/latest/bolt_defaults_reference.html

**Template file**
- [`bolt_defaults_reference.md.erb`](./templates/bolt_defaults_reference.md.erb)

**Relevant source code**
- [`config/options.rb`](../lib/bolt/config/options.rb)

To generate this documentation, run:

```shell
$ bundle exec rake docs:defaults_reference
```

### `bolt-project.yaml` options

**Documentation page**
- https://puppet.com/docs/bolt/latest/bolt_project_reference.html

**Template file**
- [`bolt_project_reference.md.erb`](./templates/bolt_project_reference.md.erb)

**Relevant source code**
- [`config/options.rb`](../lib/bolt/config/options.rb)

To generate this documentation, run:

```shell
$ bundle exec rake docs:project_reference
```

### Transport configuration options

**Documentation page**
- https://puppet.com/docs/bolt/latest/bolt_transports_reference.html

**Template file**
- [`bolt_transports_reference.md.erb`](./templates/bolt_transports_reference.md.erb)

**Relevant source code**
- [`config/transport/`](../lib/bolt/config/transport) (Each transport defines
  its available options.)
- [`config/transport/options.rb`](../lib/bolt/config/transport/options.rb)

To generate this documentation, run:

```shell
$ bundle exec rake docs:transports_reference
```

### Escalating privilege with Bolt

**Documentation page**
- https://puppet.com/docs/bolt/latest/privilege_escalation.html

**Template file**
- [`privilege_escalation.md.erb`](./templates/privilege_escalation.md.erb)

**Relevant source code**
- [`bolt_option_parser.rb`](../lib/bolt/bolt_option_parser.rb)
- [`config/transport/options.rb`](../lib/bolt/config/transport/options.rb)

To generate this documentation, run:

```shell
$ bundle exec rake docs:privilege_escalation
```
