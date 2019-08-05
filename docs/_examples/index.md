---
title: Additional Examples
index: true
---

This repository contains examples that show how you can use Bolt to automate complex tasks. Unlike the [Hands-on Lab](/), these examples are not meant to be followed in any particular order. Each example includes step-by-step instructions, commands that you can copy and paste, and project files that you can download in advance.

## Prerequisites

This exercise will help you get Bolt installed on your system. If you are unfamiliar with Bolt or the Bolt Tasks ecosystem, it may be helpful to complete our [Hands-on Lab](/) as well. It walks through the basic concepts, including how to write your own tasks and plans that can be used with Bolt.

- [Installing Bolt](../lab/01-installing-bolt)

## Examples

These examples cover more ways that you can leverage Bolt to automate complex tasks.

{% for example in site.examples %}
  {% if example.title and example.index != true %}
  * [{{ example.title }}]({{ example.url | remove: "/index.html" | relative_url }})
  {% endif %}
{% endfor %}

## Contributing Examples

Interested in contributing an example to this site? Pull requests are welcome on [GitHub](https://github.com/puppetlabs/bolt). If this is your first time contributing to Bolt, please read our [Contributing Guidelines](https://github.com/puppetlabs/bolt/blob/master/CONTRIBUTING.md).

While you are developing an example there are a couple things you should keep in mind:

* The project directory name should be descriptive
* Examples should be written in an `index.md` file and include a title and description in the front matter
* All other files should be in a directory named `Boltdir`
* Content downloaded from the Puppet Forge should not be included - use a Puppetfile instead

A complete project directory may look something like this:

```
my-bolt-example/
├── Boltdir
|   ├── inventory.yaml
|   ├── Puppetfile
|   └── site
|       └── my-module
|           ├── manifests/
|           ├── plans/
|           └── tasks/
└── index.md
```
