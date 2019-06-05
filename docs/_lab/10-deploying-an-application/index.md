---
title: Deploying an application with a plan
difficulty: Advanced
time: Approximately 20 minutes
---

In this exercise you will further explore Bolt Plans by writing a
multi-stage plan to deploy a sample application.

The sample application for this lesson consists of four nodes. It has a
single database node, two application servers, and a single load balancer in front of
them. When a new version of the application is released the following steps must be carried out:

1. Install application code on the application and database servers. `my_app::install`
1. Run migrations on the database server. `my_app::migrate`
1. For each application server:
   1. Check connections on the load balancer. `my_app::lb`
   1. Drain connections on the load balancer. `my_app::lb`
   1. Restart with the new code version. `my_app::deploy`
   1. Run a health check. `my_app_healthcheck`
   1. Add back to the load balancer. `my_app::lb`
1. Clean up the old version of the application.


# Prerequisites

For the following exercises you should have `bolt` installed and have four
Linux nodes available. The following guides will help:

1. [Acquiring Nodes](../02-acquiring-nodes)
1. [Writing tasks](../05-writing-tasks)
1. [Writing Advanced Plans](../09-writing-advanced-plans)

## Acquire nodes 

This lesson requires four nodes. If you set up nodes in [lesson 2](../02-acquiring-nodes), you need to provision an extra node.

### Provision extra nodes on Vagrant
If you set up nodes in Vagrant in lesson `02-acquiring-nodes/`, run:

```
NODES=4 vagrant up
```
> Note: Vagrantfile looks for environment variable `NODES` for number of centos nodes to provision.
> Set environmnet variable based on your shell, for example bash shell: `export NODES=4`. 

### Provision extra nodes on Docker
If you set up nodes in Docker in lesson `02-acquiring-nodes`, run:

```
docker-compose up --scale ssh=4 -d
```

When you have four nodes, update your SSH config to include them all.

## Set up inventory file
Set up an inventory file to more easily map the nodes to their role in the application. 

Assign one node to the load balancer (lb) group, one to the database (db) group and the other two to the application (app) group.

```yaml
---
groups:
  - name: lb
    nodes:
      - "0.0.0.0:32771"
  - name: db
    nodes:
      - "0.0.0.0:32770"
  - name: app
    nodes:
      - "0.0.0.0:32768"
      - "0.0.0.0:32769"
config:
  ssh:
    host-key-check: false
    # These are credentials for Docker. Manage Vagrant with SSH config.
    password: root
    user: root
```

**Note**: inventory.yaml for nodes provisioned with vagrant

```yaml
---
groups:
  - name: lb
    nodes:
      - node1
  - name: db
    nodes:
      - node2
  - name: app
    nodes:
      - node3
      - node4
config:
  ssh:
    host-key-check: false
```

Make sure your inventory is configured correctly and you can connect to all nodes. Run:

```bash
bolt command run 'echo hi' -n db,app,lb --inventoryfile ./inventory.yaml
```

## Write tasks for each stage of the application deployment

The tasks for this plan are code samples to enable us to focus on the plan itself.

```python
{% include_relative modules/my_app/tasks/install.py -%}
```

```python
{% include_relative modules/my_app/tasks/migrate.py -%}
```

```python
{% include_relative modules/my_app/tasks/lb.py -%}
```

```python
{% include_relative modules/my_app/tasks/deploy.py -%}
```

```python
{% include_relative modules/my_app/tasks/health_check.py -%}
```

```python
{% include_relative modules/my_app/tasks/uninstall.py -%}
```
## Write a plan that uses the tasks

Once you have finished writing the tasks, you can add them to a plan and automate the application deployment. The
plan performs some validation, installs the application, migrates the
database, makes the new code available on each application server and, finally, cleans up old
versions of the application.

```puppet
{% include_relative modules/my_app/plans/deploy.pp -%}
```

Run this plan with the following command. It will randomly fail 10% of the
time when the simulated load is high.

```bash
bolt plan run my_app::deploy version=1.0.2 app_servers=app db_server=db lb_server=lb --inventoryfile ./inventory.yaml --modulepath=./modules
```

The result (when simulated load is below threshold)

```plain
Starting: Check load before starting deploy on node1
Finished: Check load before starting deploy with 0 failures in 0.89 sec
Starting: Install 1.0.2 of the application on node3, node4, node2
Finished: Install 1.0.2 of the application with 0 failures in 0.89 sec
Starting: task my_app::migrate on node2
Finished: task my_app::migrate with 0 failures in 0.85 sec
Deploying to node3, currently ok with 4 open connections.
Deploy complete on Target('node3', {"connect-timeout"=>10, "tty"=>false, "host-key-check"=>false}).
Deploying to node4, currently ok with 10 open connections.
Deploy complete on Target('node4', {"connect-timeout"=>10, "tty"=>false, "host-key-check"=>false}).
Starting: Clean up old versions on node2, node3, node4
Finished: Clean up old versions with 0 failures in 0.88 sec
Plan completed successfully with no result
```

The result (when simulated load is above threshold)

```plain
Starting: Check load before starting deploy on node1
Finished: Check load before starting deploy with 0 failures in 0.89 sec
{
  "kind": "bolt/plan-failure",
  "msg": "The appplication has too many open connections: 10",
  "details": {
  }
}
```

### Parameters

```puppet
plan my_app::deploy(
  Pattern[/\d+\.\d+\.\d+/] $version,
  TargetSpec $app_servers,
  TargetSpec $db_server,
  TargetSpec $lb_server,
  String[1] $instance = 'my_app',
  Boolean $force = false
)
```

- `$version` is restricted to a string matching and `x.y.z` version format
  with the Pattern Type.
- `$app_servers`, `$db_servers`, and `$lb_server`, three TargetSpec parameters
   for the different tiers of the application. The TargetSpec type any String,
   Target or Array. By using this type we allow the command line to pass node URL
   strings, group name strings or allow another plan or JSON parameters to
   pass arrays of urls or targets.
- `$instance` the name of the instance of this application in the load balancer.
- `$force` an option to ignore errors and force the deploy to complete.


### Install application

The first step in the plan is to install the new version of the code
so all application servers can serve a new version of the assets and to migrate the
database in preparation for deploying each app server.

```puppet
  $old_version = run_task('my_app::install', [$app_servers, $db_server],
    "Install ${version} of the application",
    version => $version
  ).first['previous_version']
  run_task('my_app::migrate', $db_server)
```

The `run_task` command accepts a description argument that you can use to
provide clearer log messages for the installation step. You can include the version being
installed. Use the result of the task to store the old versions of the
application for the uninstall step.

### Loop over each application server

Now the application is staged loop over each app server and update it to use
the new code.

```puppet
  # Expand group references or globs before iterating
  get_targets($app_servers).each |$server| {

    run_task('my_app::lb', $lb_server,
      "Drain connections from ${server.name}",
      action => 'drain',
      backend => $instance,
      server => $server.name,
    )

    run_task('my_app::deploy', [$server],
      "Update application for new version",
    )

    run_task('my_app::lb', $lb_server,
      action => 'add',
      backend => $instance,
      server => $server.name,
    )
    notice("Deploy complete on ${server}.")
  }
```

To loop over targets call `get_targets` to expand any groups or globs referenced
in the `$app_servers` parameter then loop over each server with `each`. For
each server drain connections from the load balancer, deploy the new version of
application and then add the server back to the load balancer.  Afterwards log
a notice message to inform the user that the deploy is complete on that server.

### Perform checks before the deploy

The plan doesn't support multiple load balancers so validate that the
TargetSpec passed for `$lb_server` resolves to only a single target and fail
the plan otherwise. In order to prevent deploys during dangerously high load
check how many open connections the app has and fail if load is too
high.

```puppet
if get_targets($lb_server).length > 1 {
  fail_plan("${lb_server} did not resolve to a single target")
}

$conns = run_task('my_app::lb', $lb_server,
   "Check load before starting deploy",
   action => 'stats',
   backend => $instance,
   server => 'FRONTEND',
).first['connections']
if ($conns > 8) {
  fail_plan("The application has too many open connections: ${conns}")
} else {
  # Info messages will be displayed when the --verbose flag is used.
  info("Application has ${conns} open connections.")
}
```

Use the `fail_plan` function to stop the plan in both cases. `fail_plan` will
stop the current plan execution and the execution of any calling plan. It
accepts a message that will be displayed to the user if the error is not
caught.

### Check server status before deploy

```puppet
# Check stats and print a message to the user
$stats = run_task('my_app::lb', $lb_server,
  action => 'stats',
  backend => $instance,
  server => $server.name,
  _catch_errors => $force
).first
notice("Deploying to ${server.name}, currently ${stats["status"]} with ${stats["connections"]} open connections.")
```

Before starting to deploy to a server call the `my_app::lb` task with the stats
action and name of the server that is about to be deployed to and save the
result the `$stats` variable. Then use those stats to print an informative
notice about which server is going to be deployed to next.

### Suppress default log messages

Bolt logs every action on each node which results in 5 messages for each node.
By default these messages are logged at the `notice` level and can make it hard
to see the more useful `notice` messages that the plan logs directly. To make the
automatic messages log at `info` instead so they won't appear on the terminal
with the `--verbose` flag the plan wraps the loop in a
`without_default_logging` block. All code executed inside a
`without_default_logging` block including in functions or subplans will log
actions at `info` instead of `notice`.

```
without_default_logging() || {
  # Expand group references or globs before iterating
  get_targets($app_servers).each |$server| {
    # Call deploy actions here
    notice("Deploy complete on ${server}.")
  }
}
```

> Note: Pay careful attention to the empty `()` and `||`. The
> `without_default_logging` block takes no parameters but empty pipes are
> required for puppet block syntax. The `()` is required to avoid parser
> ambiguity with the empty pipes.

### Catch errors for force

```puppet
run_task('my_app::lb', $lb_server,
  "Drain connections from ${server.name}",
  action => 'drain',
  backend => $instance,
  server => $server.name,
)
```

In order to prevent execution from halting after an error when the `$force`
parameter is specified we have to use the `_catch_errors` metaparam. For each
`run_task` command  that should continue when in force mode add `_catch_errors =>
true` to the parameters.

# Next steps

Congratulations! You should now have a basic understanding of `bolt` and Bolt Tasks. Here are a few ideas for what to do next:

* Explore content on the [Bolt Tasks Playground](https://github.com/puppetlabs/tasks-playground)
* Get reusable tasks and plans from the [Task Modules Repo](https://github.com/puppetlabs/task-modules)
* Search Puppet Forge for [Tasks](https://forge.puppet.com/modules?with_tasks=yes)
* Start writing Tasks for one of your existing Puppet modules
* Head over to the [Puppet Slack](https://slack.puppet.com/) and talk to the `bolt` developers and other users
* Try out the [Puppet Development Kit](https://puppet.com/download-puppet-development-kit) [(docs)](https://docs.puppet.com/pdk/latest/index.html) which has a few features to make authoring tasks even easier

You can also move on to:

[Applying Manifest Code With Bolt](../11-apply-manifest-code)
