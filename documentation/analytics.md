# Analytics

Bolt collects data about how you use it to help the Bolt team make decisions
about how to improve it. You can opt out of providing this data.

## Opt out of data collection

You can opt out of data collection by setting an option in Bolt's configuration
or by setting an environment variable.

### Bolt configuration

To disable data collection, set `analytics: false` in your [configuration
file](configuring_bolt.md). This option is supported in the system-wide,
user-level, and project configuration files.

```yaml
# bolt-defaults.yaml
analytics: false
```

Setting the `analytics: false` option in a configuration file disables data
collection universally. You cannot override the option by setting it to `true`
in another configuration file. For example, setting `analytics: true` in a
project configuration file does not enable data collection if you've set
`analytics: false` in the system-wide or user-level configuration file.

### Environment variable

To disable data collection, set the `BOLT_DISABLE_ANALYTICS` environment
variable to any value.

```
export BOLT_DISABLE_ANALYTICS=true
```

## Data collected

Each time you run Bolt, it collects the following information and associates it
with a randomly generated, non-identifiable user UUID:

- Bolt version
- User locale
- Operating system and version
- The name of the executed command, such as `command run` or `task show`
- The names of built-in functions called from a plan
- Transports used and the number of targets using each transport
- The number of targets and groups defined in the inventory
- The number of targets targeted with a command
- The output format selected, such as `human` or `json`
- Whether the Bolt project directory was determined from the location of a
  `bolt-project.yaml` file or with the `--project` command-line option
- The number of times built-in tasks and plans are run
- The number of statements in a manifest block and how many resources that
  produces for each target
- The number of steps in a YAML plan
- The return type of a YAML plan, such as an expression or a value
- Which built-in plugins Bolt is using
- Topics viewed with `bolt guide <TOPIC>`
- IDs of any deprecation warnings
- Whether the source file for `upload_file`, `run_script`, or `file::read` plan
  functions uses an absolute path or a module path.
- Whether a task is run in no-operation mode.

## Viewing collected data

To see the data Bolt collects, add the `--log-level trace` option to your Bolt
command or use `-LogLevel trace` if you're using PowerShell.
