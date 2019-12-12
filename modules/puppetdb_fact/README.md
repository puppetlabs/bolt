# puppetdb_fact

#### Table of Contents

1. [Description](#description)
2. [Requirements](#requirements)
3. [Usage](#usage)
4. [Reference](#reference)

## Description

This module provides the puppetdb_fact plan, which collects facts for the specified targets from the configured [PuppetDB](https://puppet.com/docs/puppetdb) connection and stores the collected facts on the Targets. The updated facts can then be accessed using `mytarget.facts`.

## Requirements

This module is compatible with the version of Puppet Bolt it ships with.

## Usage

To collect facts for a set of targets using the puppetdb_fact plan, run:

```
bolt plan run puppetdb_fact --targets target1.example.com,target2.example.com
```

To run the puppetdb_fact plan from another plan run
```
run_plan(puppetdb_fact, targets => $targets )
```

### Parameters

* **targets** - The targets to collect and store facts from puppetdb for.

## Reference
