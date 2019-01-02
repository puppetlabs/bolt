# The control repository pattern

The control repository pattern is useful for creating a project that contains your tasks and plans - along with declaring modules they depend on - for others to run. It's based on the idea originally [developed for Puppet](https://github.com/puppetlabs/best-practices/blob/master/control-repo-contents.md) of a repository that acts as a single location for an organization's configuration. The base example can be found [here](https://github.com/puppetlabs/control-repo).

In Bolt, the control repository can also act as the [Boltdir](https://puppet.com/docs/bolt/1.x/configuring_bolt.html). To do so, add `bolt.yaml` (it can be an empty file) to the root of the repository.

A typical control repository for running plans will look as follows:
```

├── bolt.yaml
├── data/
├── hiera.yaml
├── Puppetfile
├── README.md
└── site/
    ├── profile/
```

Your tasks and plans would go in the `site/profile/tasks` and `site/profile/plans` directories. `hiera.yaml` is used when [applying manifest code](applying_manifest_blocks.md#) and can also be placed within the module at `site/profile/`.

The `Puppetfile` declares modules you depend on. Within the control repository, run `bolt puppetfile install` to install dependencies to the `modules/` directory. Running within this directory will see `bolt.yaml`, interpret it as a `Boltdir`, and look in the default modulepath (`site/` and `modules/`) for modules containing Bolt content.
