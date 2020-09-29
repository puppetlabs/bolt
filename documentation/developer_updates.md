# Developer updates

Find out what the Bolt team is working on and why we're making the decisions
we're making.

## September 2020

### Module management in Bolt projects

We've recently finished work on a major improvement to Bolt projects: module
management! With this improvement, you no longer need to manually manage your
modules and their dependencies in a Puppetfile and can instead automate that
process with Bolt.

So why did we make this change to how Bolt manages modules? Because managing a
project's modules could be a frustrating process that includes multiple steps:

- Find the module you want to add to your project
- Find all of the dependencies for that module
- Determine which version of each module is compatible with every other module
  you have installed
- Manually update your Puppetfile to include each module
- Install the Puppetfile

By offloading most of this work to Bolt, you now only need to list the modules
you care about in your project configuration. Bolt takes care of resolving a
module's dependencies and installing compatible versions. This greatly
simplifies the process of managing your project's modules:

- Find the module you want to add to your project
- Tell Bolt to install the module with all of its dependencies

With these changes, we've also updated where Bolt installs modules. You no
longer need to worry about accidentally overwriting local modules when you
install a Puppetfile, because Bolt installs modules to a special directory that
is not part of the configured modulepath.

The new module management feature is available starting with **Bolt 2.30.0**. To
try it out, opt in by updating your project. You can learn more about this
feature and opting in at [Managing modules in Bolt
projects](managing_modules.md).
