# minifact

#### Table of Contents

1. [Description](#description)
2. [Requirements](#requirements)
3. [Usage](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)

## Description

This module provides a collection of minifact plans all of which retrieve facts from the specified nodes but each of them processes the retrieved facts differently (if at all). The provided plans are:
* `minifact` - retrieves the facts and then stores them in the inventory, returns a result set wrapping result objects for each specified node which in turn wrap the retrieved facts
* `minifact::info` - retrieves the facts and returns information about each node's OS compiled from the `os` fact value retrieved from that node
* `minifact::retrieve` - retrieves the facts and without further processing returns a result set wrapping result objects for each specified node which in turn wrap the retrieved facts (this plan is internally used by the other two)

## Requirements

This module is compatible with the version of Puppet Bolt it ships with.

## Usage

To run the minifact plan run

```
bolt plan run minifact --nodes node1.example.com,node2.example.com
```

### Parameters

All plans have only one parameter:

* **nodes** - The nodes to retrieve the facts from.

## Reference

The core functionality is implemented in the `minifact::retrieve` plan, which runs the `minifact::bash` task for `ssh://` (and possibly `local://` if the bash shell is available on the local host) targets, the `minifact::powershell` task for `winrm://` targets and `minifact::ruby` for `pcp://` targets. Other targets are currently not supported. The tasks either run `facter --json` command if facter is available on the target and return its output or - as a fallback - compile and return information mimicking that provided by the facter's `os` fact. The plan then collects the results of the task runs on the individual nodes (and adds synthesized fail results for the unsupported nodes) and returns them wrapped in a ResultSet object.
