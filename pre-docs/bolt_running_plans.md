# Running plans

 Bolt can run plans, allowing multiple tasks to be tied together. 

To execute a task plan, run `bolt plan run`, specifying:

-   The full name of the plan, formatted as `<MODULE>::<PLAN>`.

-   Any plan parameters, as `parameter=value`.

-   The path that contains the plan's module, with the `--modulepath` flag.

-   If credentials are required to connect to the target node, pass the username and password with the `--user` and `--password` flags.


For example, if a plan defined in `mymodule/plans/myplan.pp` accepts a `load_balancer` parameter to specify a load balancer node on which to run the tasks or functions in the plan, run:

```
bolt plan run mymodule::myplan --modulepath ./PATH/TO/MODULES  load_balancer=lb.myorg.com

```

Note that, like `--nodes`, you can pass a comma-separated list of node names, wildcard patterns, or group names to a plan parameter that will be passed to a run function or that the plan resolves using `get_targets`.

**Parent topic:** [Tasks and plans](writing_tasks_and_plans.md)

