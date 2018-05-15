# Deploying an application with a plan

> **Difficulty**: Advanced

> **Time**: Approximately 20 minutes

In this exercise you will further explore Puppet Plans by writing a
multi-stage plan to deploy a dummy application.

The dummy application for this lesson consists of 4 nodes. It has a
single database node, 2+ app servers, and a single load balancer in front of
them. When a new version of the application is released the following steps must be carried out:

1. Install Application code on app and db servers. `my_app::install`
1. Run migrations on the db server. `my_app::migrate`
1. For each application server.
   1. Check connections on load balancer. `my_app::lb`
   1. Drain connections on load balancer. `my_app::lb`
   1. Restart with new code version. `my_app::deploy`
   1. Run a Health check. `my_app_healthcheck`
   1. Add back to the load balancer. `my_app::lb`
1. Clean up the old version of the application


# Prerequisites

For the following exercises you should already have `bolt` installed and have 4
linux nodes available to run commands against. The following guides will help:

1. [Acquiring Nodes](../02-acquiring-nodes)
1. [Writing tasks](../05-writing-tasks)
1. [Writing Advanced Plans](../09-writing-advanced-plans)

### Acquire nodes and set up inventory

This lesson requires 4 nodes. If you set up nodes with docker or vagrant in [lesson 2](../02-acquiring-nodes), you'll need to provision an extra node.

If you're using vagrant from the `02-acquiring-nodes/` directory run:

```
NODES=4 vagrant up
```

Then update your ssh config to include all 4 nodes.

If you're using docker from the `02-acquiring-nodes` directory run:

```
docker-compose up --scale ssh=4 -d
```

Now you'll need to set up an inventoryfile to more easily map the nodes to their role in the application. Assign one node to the lb group, one to the db group and the other two to app group.

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
    # These are credentials for docker. Manage vagrant with ssh config
    password: root
    user: root
```

Make sure your inventory is configured correctly and you can connect to all
nodes  with:

```bash
bolt command run 'echo hi' -n db,app,lb --inventoryfile ./inventory.yaml
```

# Write Tasks for each stage of the application deploy

The tasks for this plan will be dummies to enable us to focus on the plan itself.

```python
#!/usr/bin/env python
# my_app/tasks/install.py
# Install application

import json
import sys

params = json.load(sys.stdin)
json.dump(dict(status = "success", previous_version = "1.0.0", new_version = params['version']), sys.stdout)
```

```python
#!/usr/bin/env python
# my_app/tasks/migrate.py
# Migrate DB schema

import json
import sys

params = json.load(sys.stdin)
json.dump(dict(status = "success"), sys.stdout)
```

```python
#!/usr/bin/env python
# my_app/tasks/lb.py
# manipulate load_balancer

import json
import sys

from random import randint
from time import sleep

params = json.load(sys.stdin)

def stats():
    return { "connections": randint(0, 10), "status": "ok" }

def drain():
    sleep(3)
    return { "status": "success"}

def add():
    return { "status": "success" }

result_fn  = {
  "stats" : stats,
  "drain": drain,
  "add" : add,
}[params["action"]]

json.dump(result_fn(), sys.stdout)
```

```python
#!/usr/bin/env python
# my_app/tasks/deploy.py
# Update and restart the application on the new version

import json
import sys

json.dump(dict(status = "success"), sys.stdout)
```

```python
#!/usr/bin/env python
# my_app/tasks/healthcheck.py
# perform a healthcheck of a url

import json
import sys

json.dump(dict(status = "success"), sys.stdout)
```

```python
#!/usr/bin/env python
# my_app/tasks/uninstall.py
# Remove and old version of the aplication

import json
import sys

json.dump(dict(status = "success"), sys.stdout)
```
# Write a Plan that uses the tasks

These tasks can now be in a plan to automate the application deployment. The
plan will perform some validation, install the application, migrate the
database, make the new code live on each app server and finally clean up old
versions of the application.

```puppet
plan my_app::deploy(
  Pattern[/\d+\.\d+\.\d+/] $version,
  TargetSpec $app_servers,
  TargetSpec $db_server,
  TargetSpec $lb_server,
  String[1] $instance = 'my_app',
  Boolean $force = false
) {
  # Validate that there is only a single lb server to check
  if get_targets($lb_server).length > 1 {
    fail_plan("${lb_server} did not resolve to a single target")
  }

  # First query the load balancer and make sure the app isn't under too much load to do a deploy.
  unless $force {
    $conns = run_task('my_app::lb', $lb_server,
       "Check load before starting deploy",
       action => 'stats',
       backend => $instance,
       server => 'FRONTEND',
    ).first['connections']
    if ($conns > 8) {
      fail_plan("The appplication has too many open connections: ${conns}")
    } else {
      # Info messages will be displayed when the --verbose flag is used.
      info("Application has ${conns} open connections.")
    }
  }

  # Install the new version of the application and check what version was previously
  # installed so it can be deleted after the deploy.
  $old_versions = run_task('my_app::install', [$app_servers, $db_server],
    "Install ${version} of the application",
    version => $version
  ).map |$r| { $r['previous_version'] }

  run_task('my_app::migrate', $db_server)

  # Don't log every action on each node only important messages
  without_default_logging() || {
    # Expand group references or globs before iterating
    get_targets($app_servers).each |$server| {

      # Check stats and print a message to the user
      $stats = run_task('my_app::lb', $lb_server,
        action => 'stats',
        backend => $instance,
        server => $server.name,
        _catch_errors => $force
      ).first
      notice("Deploying to ${server.name}, currently ${stats["status"]} with ${stats["connections"]} open connections.")

      run_task('my_app::lb', $lb_server,
        "Drain connections from ${server.name}",
        action => 'drain',
        backend => $instance,
        server => $server.name,
        _catch_errors => $force
      )

      run_task('my_app::deploy', [$server],
        "Update application for new version",
      )

      # Verify the app server is healthy before returning it to the the load
      # balancer.
      $health = run_task('my_app::health_check', $lb_server,
        "Run Healthcheck for ${server.name}",
        target => "http://${server.name}:5000/",
        '_catch_errors' => true).first

      if $health['status'] == 'success' {
        info("Upgrade Healthy, Returning ${server.name} to load balancer")
      } else {
        # Fail the plan unless the app server is healthy or this is a forced deploy
        unless $force {
          fail_plan("Deploy failed on app server ${server.name}: ${health.result}")
        }
      }

      run_task('my_app::lb', $lb_server,
        action => 'add',
        backend => $instance,
        server => $server.name,
        _catch_errors => $force
      )
      notice("Deploy complete on ${server}.")
    }
  }

  run_task('my_app::uninstall', [$db_server, $app_servers],
    "Clean up old versions",
    live_versions => $old_versions + $version,
  )
}
```


This plan can be run with the follow command. It will randomly fail 10% of the
time when the simulated load is high.

```bash
bolt plan run my_app::deploy version=1.0.2 app_servers=app db_server=db lb_server=lb --inventoryfile ./inventory.yaml --modulepath=./modules
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
   Target or Array. By using this type we allow the CLI to pass node url
   strings, group name strings or allow another plan or JSON parameters to
   pass arrays of urls or targets.
- `$instance` the name of the instance of this application in the load balancer.
- `$force` an option to ignore errors and force the deploy to complete.


### Install application

The first step in the plan is to install the new version of the code
so all app servers can serve a new version of the assets and to migrate the
database in preparation for deploying each app server.

```puppet
  $old_version = run_task('my_app::install', [$app_servers, $db_server],
    "Install ${version} of the application",
    version => $version
  ).first['previous_version']
  run_task('my_app::migrate', $db_server)
```

The `run_task` command accepts a description argument which can be used to
provide clearer log messages for the install step including the version being
installed. Use the result of the task to store the old versions of the
application for the uninstall step.

### Loop over each App server

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
  fail_plan("The appplication has too many open connections: ${conns}")
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

Congratulations! You should now have a basic understanding of `bolt` and Puppet Tasks. Here are a few ideas for what to do next:

* Explore content on the [Puppet Tasks Playground](https://github.com/puppetlabs/tasks-playground)
* Get reusable tasks and plans from the [Task Modules Repo](https://github.com/puppetlabs/task-modules)
* Search Puppet Forge for [Tasks](https://forge.puppet.com/modules?with_tasks=yes)
* Start writing Tasks for one of your existing Puppet modules
* Head over to the [Puppet Slack](https://slack.puppet.com/) and talk to the `bolt` developers and other users
* Try out the [Puppet Development Kit](https://puppet.com/download-puppet-development-kit) [(docs)](https://docs.puppet.com/pdk/latest/index.html) which has a few features to make authoring tasks even easier
