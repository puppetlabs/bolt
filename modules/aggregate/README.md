# aggregate

#### Table of Contents

1. [Description](#description)
2. [Requirements](#requirements)
3. [Usage - Configuration options and additional functionality](#usage)

## Description

This module provides the `aggregate::count` and `aggregate::targets` plans. These plan allows you to run another task, script, or command and aggregate the results. They aggregate the results of running it across all targets as either a count of targets for each value of a key or the list of targets for each value of a key.

The plans work best with a task that produces a JSON object, and will otherwise aggregate across stdout/stderr/exitcode.

## Requirements

This module is compatible with the version of Puppet Bolt it ships with.

## Usage

To run the `aggregate::count` plan with a simple command run

```
bolt plan run aggregate::count command='ssh -V' --targets target1.example.com,target2.example.com
```

To run the `aggregate::targets` plan from another plan run
```
run_plan(aggregate::targets, targets => $targets, task => 'package', params => { 'action' => 'status', 'name' => 'sshd' } )
```

### Parameters

Both plans accept the same parameters.

#### Choose one of
* **task** - The Task to run.
* **command** - The command to execute.
* **script** - The script to execute.

#### Additional parameters

**params** - A hash of params and options to pass to the `run` function
