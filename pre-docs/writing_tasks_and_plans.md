
# Writing Puppet tasks and plans

Puppet tasks are single, ad hoc actions that you can run on target machines in
your infrastructure, allowing you to make as-needed changes to remote systems.
Plans allow you to tie tasks together for more complex operations.

Sometimes you need to do arbitrary tasks in your infrastructure that aren't
about enforcing the state of machines. You might need to restart a service, run
a troubleshooting script, or get a list of the network connections to a given
node.

You perform actions like these with either the Puppet Enterprise (PE)
orchestrator, which uses PE to connect to the remote nodes, or Bolt, a
standalone task runner. Bolt connects directly to the remote nodes with SSH or
WinRM and does not require an existing Puppet installation.

You can write tasks in any programming language that can run on the target
nodes, such as Bash, Python, or Ruby. Tasks are packaged within modules, so you
can reuse, download, and share tasks on the Forge. Task metadata describes the
task, validates input, and controls how the task runner executes the task.

Plans are sets of tasks that can be combined with other logic. This allows you
to do more complex task operations, such as running multiple tasks with one
command, computing values for the input for a task, or running certain tasks
based on results of another task. Like tasks, plans are packaged in modules and
can be shared on the Forge. Plans are written in the Puppet language.

- Writing tasks
  Tasks are similar to scripts, but they are kept in modules and can have
  metadata. This allows you to reuse and share them more easily.
- Writing plans
  Plans allow you to run more than one task with a single command, or compute
  values for the input to a task, or make decisions based on the result of
  running a task.
