# Connecting Bolt to Puppet Enterprise

If you're a Puppet Enterprise (PE) customer, you can connect Bolt to PE using
the Puppet Communications Protocol (PCP) transport. However, in most cases this
is not necessary, because tasks and plans are already supported from the console
or the command line using
[PE orchestrator](https://puppet.com/docs/pe/latest/running_jobs_with_puppet_orchestrator_overview.html).
Wherever possible, we recommend using PE tasks and plans instead of connecting
Bolt to PE over PCP. 

For more information on tasks and plans in PE, see [Orchestrating tasks and plans](https://puppet.com/docs/pe/latest/orchestrating_puppet_and_tasks.html).

For information on connecting Bolt to PE using the `bolt-shim` module, see
[Connecting Bolt to
PE](https://github.com/puppetlabs/puppetlabs-bolt_shim/blob/master/docs/connect_bolt_pe.md).
