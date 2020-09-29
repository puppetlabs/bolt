# Inspecting tasks

Before you run a task in your environment, inspect the task to determine what
effect it has on your targets.

## Run in no operation mode

You can run some tasks in no-operation mode (`noop`) to view changes without
taking any action on your targets. This way, you ensure the tasks perform as
designed. If a task doesn't support no-operation mode, you get an error.

```
bolt task run package name=vim action=install --noop -n example.com
```

## Show a task list

View a list of what tasks are installed in the current modulepath. Note that
tasks marked with the `private` metadata key are not shown:

```
bolt task show
```

## Show documentation for a task

View parameters and other details for a task, including whether a task supports
`--noop`:

```
bolt task show <TASK NAME>
```