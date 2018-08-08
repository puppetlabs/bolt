# Running tasks

Bolt can run Puppet tasks on remote nodes without requiring any Puppet infrastructure. 

To execute a task, run `bolt task run`, specifying:

-   The full name of the task, formatted as `<MODULE::TASK>`, or as `<MODULE>` for a module's main task \(the `init` task\).

-   Any task parameters, as `parameter=value`.

-   The nodes on which to run the task and the connection protocol, with the `--nodes` flag.

-   The module path that contains the plan's module, with the `--modulepath` flag.

-   If credentials are required to connect to the target node, the username and password, with the `--user` and `--password` flags.


For example, to run the `sql` task from the `mysql` module on node named neptune:

```
bolt task run mysql::sql database=mydatabase sql="SHOW TABLES" --nodes neptune --modulepath ~/modules
```

To run the main module task defined in `init`, refer to the task by the module name only. For example, the `puppetlabs-package` module contains only one task, defined as `init`, but this task can execute several actions. To run the `status` action from this module to check whether the vim package is installed, you run:

```
bolt task run package action=status name=vim --nodes neptune --modulepath ~/modules
```

**Parent topic:** [Tasks and plans](writing_tasks_and_plans.md)

