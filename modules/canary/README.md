# canary

#### Table of Contents

1. [Description](#description)
2. [Requirements](#requirements)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)

## Description

This module provides the canary plan. This plan allows you to run another task, script, or command in canary mode. First the action will be executed on a small number of nodes and only if it succeeds will it run on the rest. Failure Result objects are generated for any node the plan skips and a ResultSet is returned so the plan can be called from another plan in place of the run function that it wraps.

## Requirements

This module is compatible with the version of Puppet Bolt it ships with.

## Usage

To run the canary plan with a simple command run

```
bolt plan run canary command='echo hi' --nodes node1.example.com,node2.example.com
```

To see it handling failures run

```
bolt plan run canary command='exit 1' --nodes node1.example.com,node2.example.com
```

To run the canary plan from another plan run
```
run_plan(canary, nodes => $nodes, task => 'my_app::upgrade', params => { 'version' = => '1.0.4' } )
```

### Parameters

#### Choose one of
* **task** - The Task to run.
* **command** - The command to execute.
* **script** - The script to execute.

#### Additional parameters

**params** - A hash of params and options to pass to the `run` function

**canary_size** - How many nodes should be included in the canary group. default: 1

## Reference

This plan returns a single ResultSet. The Result will be used for any node the plan attempted to execute on. If the node was skipped an error with the kind `canary/skipped-node` will be generated.
