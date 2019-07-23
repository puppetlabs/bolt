---
title: Additional Examples
index: true
---

This repository contains examples that show how you can use Bolt to automate complex tasks. Unlike the [Hands-on Lab](/), these examples are not meant to be followed in any particular order. Each example includes step-by-step instructions, commands that you can copy and paste, and project files that you can download in advance.

## Prerequisites

This exercise will help you get Bolt installed on your system. If you are unfamiliar with Bolt or the Bolt Tasks ecosystem, it may be helpful to complete our [Hands-on Lab](/) as well. It walks through the basic concepts, including how to write your own tasks and plans that can be used with Bolt.

- [Installing Bolt](lab/01-installing-bolt)

## Examples

These examples cover more ways that you can leverage Bolt to automate complex tasks.

{% for example in site.examples %}
  {% if example.title and example.index != true %}
  * [{{ example.title }}]({{ example.url | remove: "/index.html" | relative_url }})
  {% endif %}
{% endfor %}

{% include_relative CONTRIBUTING.md %}