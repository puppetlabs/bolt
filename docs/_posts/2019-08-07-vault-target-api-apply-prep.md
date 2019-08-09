---
title: Vault, the Target API, and apply_prep
---

Welcome to the *first ever* Bolt developer update! This is a new experiment we're trying to communicate more directly about what we're actively working on and what we're thinking about in the near term.

This week, we released Bolt 1.28.0. The feature I want to highlight is the new Vault plugin. This plugin allows you to query inventory information (such as passwords) from [HashiCorp Vault](https://www.vaultproject.io/).

As an example, this inventory snippet retrieves a private key from Vault and uses it to connect to `host.example.com`.

```yaml
targets:
  - host.example.com
config:
  ssh:
    user: root
    private-key:
      key-data:
        _plugin: vault
        server_url: http://127.0.0.1:8200
        auth:
          method: userpass
          user: bolt
          pass: bolt
        path: secrets/bolt
        field: private-key
        version: 2
```

Try out the plugin and let us know what you think.

## Up next

Coming down the pipe, Alex posted [a specification](https://github.com/puppetlabs/bolt/issues/1125) for some refinements to the Target/inventory API. Our aim with that is to standardize the operations you can use within a plan to dynamically create, modify, and regroup targets.

We've also started discussing extensions to the `apply_prep()` function to make it possible to use custom agent install methods and alternate fact sources. Please check out the [current state of that proposal](https://github.com/puppetlabs/bolt/issues/1123) and give feedback.

Speaking of feedback, please reach out in `#bolt` on Slack or by email to let us know what you think of this newsletter format.
