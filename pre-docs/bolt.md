# Bolt

Puppet Bolt is an open source task runner that executes ad hoc tasks, scripts,
and commands across your infrastructure and applications.

Bolt is great for troubleshooting, deploying on-demand changes, distributing
scripts to run across your infrastructure, or automating changes that need to
happen in a particular order as part of an application deployment.

Bolt has a command line interface and connects to remote systems with SSH and
WinRM, so it doesn't require you to install any agent software. Tasks are
reusable and shareable in modules on the Forge, and can be written in any
scripting or programming language.

- With Bolt you can:
- Execute commands on remote systems.
- Distribute and execute scripts written in Bash, PowerShell, Python, and other languages.
- Run Puppet tasks or task plans on remote systems that don't have Puppet installed.
- Use authentication methods such as passwords and public keys.

> Tip: Bolt uses an internal version of Puppet that supports executing tasks and
> plans, so you do not need to install Puppet. If you use Bolt on a machine that
> has Puppet installed, then Bolt uses its internal version of Puppet and does
> not conflict with the Puppet version you have installed.


## Bolt is in development

Puppet Bolt is in a pre-1.0 release. This means, per the Semantic Versioning
guidelines, that Bolt is still in development and is subject to frequent
change, ongoing feature iteration, and improvements. You should expect to
upgrade frequently and read the release notes for each version. For more
information about semantic versioning guidelines, see the Semantic Versioning
specifications.


## Bolt release notes
Release notes for the Bolt 0.x release series.

- Installing Bolt
  Install Bolt and any dependencies for your operating system, such as Ruby, a
  GNU Compiler Collection (GCC) compiler and the Bolt gem.

- Configuring Bolt
  Create a config file to store and automate the CLI flags you use every time you run Bolt.

- Running Bolt commands
  Bolt executes ad hoc commands, runs scripts, uploads files, and runs Puppet tasks or task plans on remote nodes from a controller node, such as your laptop or workstation.

- Running tasks and plans with Bolt
  Bolt can run Puppet tasks and plans on remote nodes without requiring any pre-existing Puppet infrastructure.

- Bolt command options
  Bolt commands can accept several command line options, some of which are required to run certain bolt commands.
