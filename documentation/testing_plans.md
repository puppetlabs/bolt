# Testing plans

Bolt ships with a library of helpers, named `BoltSpec`, intended to be used for
writing unit tests for plans with the `RSpec` testing tool. Before writing unit
tests for plans, get familiar with [RSpec](https://rspec.info/).

`BoltSpec` requires other Puppet testing tools like `rspec-puppet`. The [Puppet
Development Kit (PDK)](https://puppet.com/docs/pdk/latest/pdk.html) provides
commands for installing and configuring these tools in new or existing modules.
If your plan is part of a Bolt project, you can either move the plan to a module
created with PDK or [manually setup
rspec-puppet](https://rspec-puppet.com/documentation/setup/) in your Bolt
project.

## Set up the test environment

Before you can write and run tests, you need to set up the test environment.

1. Install [Ruby](https://www.ruby-lang.org/en/documentation/installation/).

1. Install the [Puppet Development Kit
   (PDK)](https://puppet.com/docs/pdk/latest/pdk_install.html), which is used to
   develop Puppet modules and provides integrated testing tools.

1. Create a [new
   module](https://puppet.com/docs/pdk/latest/pdk_creating_modules.html) using
   `pdk new module` or [convert an existing
   module](https://puppet.com/docs/pdk/latest/pdk_converting_modules.html) with
   `pdk convert`.

1. Ensure your module has `Gemfile`, `Rakefile`, and `spec/spec_helper.rb`
   files.

1. Install the module's gem dependencies, which include Bolt and other testing
   tools:

    ```shell
    pdk bundle install
    ```

## Directory and file structure

Save tests to the same module as the plans you are testing. By convention, tests
for a plan are saved to a file with the name `<PLAN NAME>_spec.rb` in the
module's `spec/plans` directory.

```shell
my_module/
├── Gemfile
├── metadata.json
├── plans/
│   └── my_plan.pp
├── Rakefile
└── spec/
    ├── plans/
    │   └── my_plan_spec.rb
    └── spec_helper.rb
```


## Include BoltSpec functions

To use the `BoltSpec` library functions, include them in either the
`spec_helper.rb` file or in the individual test files, and configure Puppet and
Bolt for the testing environment.

> 🔩 **Tip**: Unless your module also includes tests for manifest code, add the
> `BoltSpec` helpers and configure Puppet and Bolt in `spec_helper.rb` instead
> of including them in the individual test files. This makes the helpers
> available to all of your tests.

### Include BoltSpec in spec_helper.rb

To expose the `BoltSpec` library functions and configure Puppet and Bolt for all
tests in the `spec/` directory, add the following lines to the `spec_helper.rb`
file:

```ruby
# spec/spec_helper.rb

# Load the BoltSpec library
require 'bolt_spec/plans'

# Include the BoltSpec library functions
include BoltSpec::Plans

# Configure Puppet and Bolt for testing
BoltSpec::Plans.init

# Additional spec_helper configuration . . .
```

### Include BoltSpec in test files

You can expose the `BoltSpec` helper functions and configure Puppet and Bolt for
individual test files by adding the functions directly in the file instead of
adding them to `spec_helper.rb`. You should do this if your module includes
tests for manifest code, as configuring Puppet and Bolt in `spec_helper.rb`
might cause your manifest tests to fail.

To include `BoltSpec` helpers and configure Puppet and Bolt for a single test
file, add the following lines to the file:

```ruby
# spec/plans/<PLAN NAME>_spec.rb

# Load the spec_helper and BoltSpec library
require 'spec_helper'
require 'bolt_spec/plans'

describe '<PLAN NAME>' do
  # Include the BoltSpec library functions
  include BoltSpec::Plans

  # Configure Puppet and Bolt before running any tests
  before(:all) do
    BoltSpec::Plans.init
  end

  # Tests . . .
end
```

## Running tests

To run tests for your modules, including tests that you write for plans, run the
following command:

```shell
pdk bundle exec rake spec
```

This command runs a rake task that is defined in the `Rakefile` created by PDK,
and should execute successfully before you have written any tests. After you've
written tests and run the rake task, the task prints a list of your tests to the
console together with each test's pass or fail status.

To run tests for a single plan, run the following:

```shell
pdk bundle exec rake spec_prep
pdk bundle exec rspec spec/plans/<TEST FILE>
pdk bundle exec rake spec_clean
```

## Configuration

By default, the testing environment uses Bolt's default configuration and an
empty inventory. The one exception is that Bolt's modulepath is configured to
the modulepath set up for `rspec-puppet`.

You can create your own values for Bolt's configuration, inventory, and
modulepath by overriding the helper functions that set them. You can write these
functions in the `spec_helper.rb` file, which exposes them to all tests, or in
individual test files.

### Overriding configuration

To override the default configuration used by `BoltSpec`, write a `config_data`
function in either your `spec_helper.rb` file or in the individual test files.
This function should return a hash of configuration data that matches the
structure expected in a [configuration file](bolt_project_reference.md).

For example, the following `config_data` function loads configuration data from
a test fixture:

```ruby
def config_data
  YAML.load_file(File.expand_path('../fixtures/config.yaml'))
end
```

### Overriding inventory

To override the default inventory used by `BoltSpec`, write an `inventory_data`
function. This function should return a hash of inventory data that matches the
structure expected in an [inventory file](inventory_files.md).

For example, the following `inventory_data` function loads inventory data from a
test fixture:

```ruby
def inventory_data
  YAML.load_file(File.expand_path('../fixtures/inventory.yaml'))
end
```

### Overriding the modulepath

To override the default modulepath used by `BoltSpec`, write a `modulepath`
function. This function should return an array of strings, where each string is
the path to a directory that includes modules.

```ruby
def modulepath
  [File.expand_path('../fixtures/modules')]
end
```

## Running plans

The `BoltSpec` library includes the `run_plan` function which is used to run a
plan. It has two required parameters: the name of the plan and a set of
parameters to pass to the plan.

To run a plan in a test, call the `run_plan` function:

```ruby
it 'calls the plan' do
  run_plan('configure', { 'cleanup' => false })
end
```

The `run_plan` function returns a [`PlanResult`
object](bolt_types_reference.md#planresult), which you can examine and make
assertions on. For example, if you expect your plan to succeed and return a
message, you can write a test that makes those assertions.

Given the following plan which returns a message:

```puppet
plan whoami () {
  return 'Who are YOU?'
}
```

You can write a test that asserts that the plan will return a successful result
with the message `Who are YOU?`:

```ruby
it 'asks who you are' do
  result = run_plan('whoami', {})

  expect(result.ok?).to be(true)
  expect(result.value).to eq('Who are YOU?')
end
```

## Stubs and mocks

The `BoltSpec` library includes several functions used to mock and stub plan
functions in unit tests for plans. It's important to understand the difference
between stubs and mocks when writing your tests, as they serve different
purposes.

- Use _stubs_ to allow the invocation of plan functions and set their return
  values.

- Use _mocks_ to make assertions about plan function invocations and set their
  return values.

A helpful way to remember the difference between a stub and a mock, and when to
use one or the other, is that stubs _allow_ you to invoke plan functions, while
mocks _expect_ you to invoke plan functions. Each stub and mock function
available in `BoltSpec` starts with `allow_` or `expect_` to denote whether it
is a stub or a mock.

### Supported stubs and mocks

You can stub or mock the following functions. Click on each function to view its
documentation.

| plan function | Stub function | Global stub function | Mock function
| --- | --- | --- | --- |
| [`apply`](plan_functions.md#apply) | [`allow_apply`](boltspec_reference.md#allow-apply) | - | - |
| [`apply_prep`](plan_functions.md#apply-prep) | [`allow_apply_prep`](boltspec_reference.md#allow-apply-prep) | - | - |
| [`download_file`](plan_functions.md#download-file) | [`allow_download`](boltspec_reference.md#allow-download) | [`allow_any_download`](boltspec_reference.md#allow-any-download) | [`expect_download`](boltspec_reference.md#expect_download) |
| [`out::message`](plan_functions.md#outmessage) | [`allow_out_message`](boltspec_reference.md#allow-out-message) | [`allow_any_out_message`](boltspec_reference.md#allow-any-out-message) | [`expect_out_message`](boltspec_reference.md#expect-out-message) |
| [`out::verbose`](plan_functions.md#outverbose) | [`allow_out_verbose`](boltspec_reference.md#allow-out-verbose) | [`allow_any_out_verbose`](boltspec_reference.md#allow-any-out-verbose) | [`expect_out_verbose`](boltspec_reference.md#expect-out-verbose) |
| [`run_command`](plan_functions.md#run-command) | [`allow_command`](boltspec_reference.md#allow-command) | [`allow_any_command`](boltspec_reference.md#allow-any-command) | [`expect_command`](boltspec_reference.md#expect-command) |
| [`run_plan`](plan_functions.md#run-plan) | [`allow_plan`](boltspec_reference.md#allow-plan) | [`allow_any_plan`](boltspec_reference.md#allow-any-plan) | [`expect_plan`](boltspec_reference.md#expect-plan) |
| [`run_script`](plan_functions.md#run-script) | [`allow_script`](boltspec_reference.md#allow-script) | [`allow_any_script`](boltspec_reference.md#allow-any-script) |[`expect_script`](boltspec_reference.md#expect-script) |
| [`run_task`](plan_functions.md#run-task) | [`allow_task`](boltspec_reference.md#allow-task) | [`allow_any_task`](boltspec_reference.md#allow-any-task) | [`expect_task`](boltspec_reference.md#expect-task) |
| [`upload_file`](plan_functions.md#upload-file) | [`allow_upload`](boltspec_reference.md#allow-upload) | [`allow_any_upload`](boltspec_reference.md#allow-any-upload) | [`expect_upload`](boltspec_reference.md#expect-upload) |

### Modifiers

Stubs and mocks support modifiers that allow you to add specificity to your
tests. Modifiers do any of the following:

- Restrict the number of times a plan function can be invoked or is expected to
  be invoked.

- Specify the arguments that a plan function is invoked with.

- Set the value returned by a plan function.

For example, you can use the `be_called_times` modifier to limit the number of
times you expect a task to be run in a plan. The following test sets an
assertion that the `facts` task is only called once:

```ruby
it 'does not run more than two tasks' do
  # Assert that the 'facts' task is run exactly once
  expect_task('facts').be_called_times(1)

  # Run the plan
  run_plan('my_project::my_plan', 'servers' => 'servers', 'databases' => 'databases')
end
```

This test would pass for the following plan, since the plan only runs the
`facts` task once:

```puppet
plan my_project::my_plan (
  TargetSpec $servers,
  TargetSpec $databases
) {
  $targets = $servers + $databases
  $results = run_task('facts', $targets)
  return $results
}
```

However, the test would fail for the following plan, since the plan runs the
`facts` task twice:

```puppet
plan my_project::my_plan (
  TargetSpec $servers,
  TargetSpec $databases
) {
  $server_results   = run_task('facts', $servers)
  $database_results = run_task('facts', $databases)
  $results          = ResultSet.new($server_results.results + $database_results.results)
  return $results
}
```

You can chain modifiers, allowing you to add as much or as little specificity to
a stub or mock as you want. For example, you can restrict a task to run on a
specific list of targets with a specific set of parameters:

```ruby
it 'configures servers' do
  # Assert that the 'my_project::configure' task is run
  expect_task('my_project::configure').with_targets('servers').with_params({ 'confpath' => '/path/to/conf' })

  # Run the plan
  run_plan('my_project::configure', 'targets' => ['servers', 'databases'])
end
```

📖  **Related information**

- See the [BoltSpec reference](boltspec_reference.md) for a full list of
  modifiers.

### Matching stubs and mocks

When you run your tests and a plan invokes a plan function, `BoltSpec` matches
the function invocation to any stubs or mocks created for the test. `BoltSpec`
matches plan function invocations to any stub or mock that is as specific or
less specific than the function invocation, but not to any stub or mock that is
more specific than the function invocation. If the function invocation matches
multiple stubs or mocks, `BoltSpec` uses the last stub or mock that matched.

For a test to pass, `BoltSpec` must find a match for each mock in the test. 

For example, the following plan invokes the `run_task` function to run the
`configure` task on a list of targets:

```puppet
plan configure (
  TargetSpec $targets
) {
  $result = run_task('configure', $targets)
  return $result
}
```

Given the following test which has three `expect_task` mocks:

```ruby
it 'runs the configure task' do
  expect_task('configure')
  expect_task('configure').with_targets(['servers'])
  expect_task('configure').with_targets(['servers']).with_params('autoupdate' => true)

  run_plan('configure', 'targets' => 'servers')
end
```

`BoltSpec` matches the `run_task` invocation to the following mocks:

```ruby
expect_task('configure')
expect_task('configure').with_targets(['servers'])
```

`BoltSpec` does not match the `run_task` invocation to the third mock because it
uses the `with_params` modifier to add more specificity. Because `BoltSpec`
found multiple matching mocks, it uses the last matching mock defined in the
test: `expect_task('configure').with_targets(['servers'])`. The test fails, as
the first and third mocks are not fulfilled.

It's important to remember that `BoltSpec` uses the last matching stub or mock
and write your tests accordingly by creating your stubs and mocks in the correct
order. Otherwise, your test might fail even though your plan's logic is sound.

For example, the following plan runs the `configure` task twice. The first task
run sets the `autoupdate` parameter, while the second task run does not.

```puppet
plan configure_twice (
  TargetSpec $targets
) {
  run_task('configure', $targets, 'autoupdate' => true)
  run_task('configure', $targets)
}
```

The following test creates two mocks. The first mock asserts that the
`configure` task is run with the parameter `autoupdate => true`, while the
second mock just asserts that the `configure` task is run.

```ruby
it 'configures servers and databases' do
  expect_task('configure').with_params('autoupdate' => true)
  expect_task('configure')

  run_plan('configure_twice', 'targets' => 'servers')
end
```

When the test is run, `BoltSpec` matches the first `run_task` invocation to both
mocks, but uses the last matching mock: `expect_task('configure')`. When the
plan invokes `run_task` a second time, the invocation only matches one mock:
`expect_task('configure')`. The test fails because the
`expect_task('configure')` mock is only expected to be matched once and the test
never used the first `expect_task('configure').with_params('autoupdate' =>
true)` mock.

Writing the test with the mocks in the opposite order results in the test
passing:

```ruby
it 'configures servers and databases' do
  expect_task('configure')
  expect_task('configure').with_params('autoupdate' => true)

  run_plan('configure_twice', 'targets' => 'servers')
end
```

### Stubbing and Mocking PuppetDB Calls

Plans that use the `puppetdb_*` set of functions can stub and mock values
to PuppetDB using standard RSpec mechanisms on `puppetdb_client`, which is
an automatically provided instance of the PuppetDB client in the
`BoltSpec` testing context.

If you attempt to test a plan that uses one of the `puppetdb_*` functions
and have not stubbed or mocked the invocation then BoltSpec will raise an
error similar to: `Bolt::PAL::PALError: undefined method 'make_query' for #<BoltSpec::Plans::MockPuppetDBClient:0x0000000004745500>` where the method
you need to stub/mock will depend on which of the `puppetdb_*` set of
functions you called.

List of methods to stub/mock on the `puppetdb_client` instance for each
Bolt function:

- `puppetdb_command`: `send_command(command, version, payload)`
- `puppetdb_fact`: `facts_for_node(certnames)`
- `puppetdb_query`: `make_query(query)`

You may use the standard RSpec approach to stub and mock. For example, using
RSpec mocking to stub a query:

```ruby
it 'runs a plan that needs puppetdb_query' do
  allow(puppetdb_client).to receive(:make_query)
    .with('nodes [certname] { limit 1 }')
    .and_return([ {'certname' => 'mynode'} ])

  run_plan('pdb_using_plan', 'targets' => 'servers')
end
```

## Execution modes

Plans often execute sub-plans with the `run_plan` function to build complex
workflows. When testing these plans, it might be helpful to execute any
sub-plans as well without needing to stub or mock the plan. To support this,
`BoltSpec` offers two different execution modes:

- `execute_any_plan`

  **Default mode.** When running in this mode, `BoltSpec` runs any plan invoked
  with the`run_plan` function as long as that plan is not stubbed or mocked. If
  a plan is stubbed or mocked while running in this mode, `BoltSpec` honors the
  stub or mock and does not execute the plan.

- `execute_no_plan`

  If a test is run in `execute_no_plan` mode, `BoltSpec` does not run any plan
  that is invoked with the `run_plan` function. If `BoltSpec` encounters a
  `run_plan` function and it is not stubbed or mocked, the test fails. This mode
  is useful for ensuring that your plan is not running any unexpected sub-plans.
  Test authors should stub or mock all sub-plans that might be invoked during a
  test.

You can set the execution mode by invoking the appropriate function in your
tests.

For example, to set the execution mode for a single test:

```ruby
describe 'my_project::my_plan' do
  it 'executes a task without running sub-plans' do
    execute_no_plan

    # Test code . . .
  end
end
```

You can also set the execution mode for multiple tests:

```ruby
describe 'my_project::my_plan' do
  before(:all) do
    execute_no_plan
  end

  include_examples 'generic plan tests'
end
```

## Examples

### Testing a plan with conditional logic

The following example demonstrates testing a plan with simple conditional logic.

This plan accepts three parameters: `command`, `script`, and `targets`. If a
`command` is passed to the plan, the command is run on the targets. Likewise, if
a `script` is passed to the plan, the script is run on the targets. The plan
expects one of either `command` or `script` to be provided, and fails with a
helpful message if neither parameter is specified or if both parameters are
specified.

Save the following plan to `command_or_script/plans/init.pp`:

```puppet
# Run either a command or a script. Fails if neither or both a command and script
# are specified.
#
# @param command The command to run.
# @param script The script to run.
# @param targets The targets to run the command or script on.
#
plan command_or_script (
  TargetSpec       $targets,
  Optional[String] $command = undef,
  Optional[String] $script  = undef
) {
  if type($command) == Undef and type($script) == Undef {
    fail_plan('Must specify either command or script.')
  }
  elsif $command and $script {
    fail_plan('Cannot specify both command and script.')
  }
  elsif $command {
    return run_command($command, $targets)
  }
  else {
    return run_script($script, $targets)
  }
}
```

As a plan author, you might want to ensure each code path executes as you
expect. To do so, you can write a few tests that assert the following behavior:

- The plan fails with a helpful message if neither `command` nor `script` are
  specified.

- The plan fails with a helpful message if both `command` and `script` are
  specified.

- The plan succeeds and returns a value if `command` is specified.

- The plan succeeds and returns a value if `script` is specified.

Because the tests include assertions about the `run_script` function, you need
to ensure the script that you pass to the mocks and stubs exists. This is
because Bolt validates that a script exists when it invokes the `expect_script`
mock. In the following tests, the path to the script is
`command_or_script/script.rb`, which is a file in the module's files directory
at `command_or_script/files/script.rb`.

Save the following tests to `command_or_script/spec/plans/init_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'test' do
  include BoltSpec::Plans

  # Configure Puppet and Bolt before running any tests
  before(:all) do
    BoltSpec::Plans.init
  end

  let(:command) { 'whoami' }
  let(:plan)    { 'command_or_script' }
  let(:script)  { 'command_or_script/script.rb' }
  let(:targets) { 'localhost' }

  it 'fails if neither command nor script are specified' do
    result = run_plan(plan, 'targets' => targets)

    expect(result.ok?).to be(false)
    expect(result.value.msg).to match(/Must specify either command or script/)
  end

  it 'fails if both command and script are specified' do
    result = run_plan(plan, 'command' => command, 'script' => script, 'targets' => targets)

    expect(result.ok?).to be(false)
    expect(result.value.msg).to match(/Cannot specify both command and script/)
  end

  it 'runs the specified command on the targets and returns a value' do
    expect_command(command).with_targets(targets).always_return('stdout' => 'localhost')

    result = run_plan(plan, 'command' => command, 'targets' => targets)

    expect(result.ok?).to be(true)
    expect(result.value.first['stdout']).to match(/localhost/)
  end

  it 'runs the specified script on the targets and returns a value' do
    expect_script(script).with_targets(targets).always_return('stdout' => 'success')

    result = run_plan(plan, 'script' => script, 'targets' => targets)

    expect(result.ok?).to be(true)
    expect(result.value.first['stdout']).to match(/success/)
  end
end
```

Run the tests:

```shell
pdk bundle exec rake spec
```

### Testing a plan with sub-plans

The following example demonstrates testing a plan that runs sub-plans.

This plan accepts a single parameter: a list of targets to run on. First, the
plan runs a sub-plan to group targets depending on whether the `puppet-agent`
package is installed. Then, the plan runs the `patch` task on any targets with
the `puppet-agent` package installed and the `puppet_agent::install` task on any
targets without the `puppet-agent` package installed.

Save the following plan to `patch/plans/init.pp`:

```puppet
# Apply patches to agent targets and install the agent package on
# targets without an agent.
#
# @param targets The targets to patch.
#
plan patch (
  TargetSpec $targets
) {
  # Group targets by puppet-agent status
  $_targets = run_plan('patch::get_targets', 'targets' => $targets)

  # Run the patching task on targets with agents
  unless $_targets['agents'].empty() {
    run_task('patch', $_targets['agents'])
  }

  # Install the puppet-agent package on agentless targets
  unless $_targets['agentless'].empty() {
    run_task('puppet_agent::install', $_targets['agentless'])
  }

  # Return the targets grouped by puppet-agent status
  return $_targets
}
```

The plan executes the following sub-plan. The sub-plan runs the
`puppet_agent::version` task on each target and groups targets depending on
whether the target has the `puppet-agent` package installed. It returns a hash
that indicates which targets have the `puppet-agent` packaged installed and
which do not.

Save the following plan to `patch/plans/get_targets.pp`:

```puppet
# Group targets by their agent status.
#
# @param targets The targets to check agent status for.
#
plan patch::get_targets (
  TargetSpec $targets
) {
  # Get puppet-agent version on all targets
  $_targets = get_targets($targets) 
  $results  = run_task('puppet_agent::version', $_targets)

  # Group targets by puppet-agent status
  $agents    = $results.filter_set |$result| { $result['version'] != undef }.targets
  $agentless = $results.filter_set |$result| { $result['version'] == undef }.targets

  return({
    'agents'    => $agents,
    'agentless' => $agentless
  })
}
```

As a plan author, you might want to ensure the `patch::get_targets` sub-plan
correctly returns a hash with targets grouped by `puppet-agent` status, and then
run the appropriate task on each group of targets. To do so, you can write a few
tests that assert the following behavior:

- The sub-plan groups targets by their `puppet-agent` status and returns a hash
  with these groups.

- The sub-plan returns an empty array for a group that has no member targets.

- The plan runs the `patch` task on targets with agents.

- The plan does not run the `patch` task if there are no targets with agents.

- The plan runs the `puppet_agent::install` task on agentless targets.

- The plan does not run the `puppet_agent::install` task if there are no
  agentless targets.

The plan and sub-plan both run tasks in the `puppet_agent` module. To ensure
this module is available to the tests, you can add it to the `.fixtures.yml`
file in the module's root directory. Because the `puppet_agent` module also uses
files from the `facts` module, include that module as well.

```yaml
# .fixtures.yml
fixtures:
  forge_modules:
    puppet_agent:
      repo: "puppetlabs/puppet_agent"
      ref: "4.4.0"
    facts:
      repo: "puppetlabs/facts"
      ref: "1.4.0"
```

Because the plan invokes the `get_targets` function, which accesses Bolt's
inventory to retrieve `Target` objects, the tests must include an inventory. You
can override the default inventory in `BoltSpec` using the `inventory_data`
function.

By default, `BoltSpec` tests run in `execute_any_plan` mode, which means the
`patch::get_targets` plan is run in each test. For tests where it is not
necessary to make assertions about the sub-plan, you can stub the sub-plan and
have it return a set value.

Save the following tests to `patch/spec/plans/init_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'patch' do
  include BoltSpec::Plans

  # Inventory that is loaded by Bolt with targets that can be referenced
  # by name in stubs and mocks
  def inventory_data
    {
      'groups' => [
        {
          'name'    => 'agents',
          'targets' => ['agent-target']
        },
        {
          'name'    => 'agentless',
          'targets' => ['agentless-target']
        },
        {
          'name'    => 'empty',
          'targets' => []
        }
      ]
    }
  end

  # Configure Puppet and Bolt before running any tests
  before(:all) do
    BoltSpec::Plans.init
  end

  # Set the return value of puppet_agent::version for each target
  # Stub the patch and puppet_agent::install tasks
  before(:each) do
    allow_task('puppet_agent::version').return_for_targets({
      'agent-target'     => { 'version' => '7.0.0' },
      'agentless-target' => { 'version' => nil }
    })

    allow_task('patch')
    allow_task('puppet_agent::install')
  end

  it 'groups targets by puppet-agent status' do
    result = run_plan('patch', 'targets' => 'all')

    expect(result.value['agents'].map(&:name)).to eq(['agent-target'])
    expect(result.value['agentless'].map(&:name)).to eq(['agentless-target'])
  end

  it 'returns an empty array if a group has no targets' do
    result = run_plan('patch', 'targets' => 'empty')

    expect(result.value['agents']).to eq([])
    expect(result.value['agentless']).to eq([])
  end

  it 'runs the patch task on targets with agents' do
    expect_task('patch').with_targets(['agent-target'])

    run_plan('patch', 'targets' => 'all')
  end

  it 'does not run the patch task if there are no targets with agents' do
    expect_task('patch').not_be_called

    run_plan('patch', 'targets' => 'agentless')
  end

  it 'runs the puppet_agent::install task on agentless targets' do
    expect_task('puppet_agent::install').with_targets(['agentless-target'])

    run_plan('patch', 'targets' => 'all')
  end

  it 'does not run the puppet_agent::install task if there are no agentless targets' do
    expect_task('puppet_agent::install').not_be_called

    run_plan('patch', 'targets' => 'agents')
  end
end
```

Run the tests:

```shell
pdk bundle exec rake spec
```

### Testing a plan that uses `run_task_with`

The following example demonstrates testing a plan that uses the [`run_task_with()`
plan function](plan_functions.md#run-task-with).

This plan accepts two parameters: `sql` and `targets`. The plan executes SQL on
a Postgres database using the `postgresql::sql` task. Each target has a
different user and password configured for the database, which is listed in the
inventory file under each target's `vars` field. The user and password are
passed to the task as target-specific parameters using the `run_task_with()`
function.

Save the following plan to `sql/plans/init.pp`:

```puppet
# Execute SQL.
#
# @param sql The SQL.
# @param targets The targets to execute the SQL on.
#
plan sql (
  String     $sql,
  TargetSpec $targets
) {
  $results = run_task_with('postgresql::sql', $targets) |$target| {
    {
      'sql'      => $sql,
      'password' => $target.vars['postgres_password'],
      'user'     => $target.vars['postgres_user']
    }
  }

  return $results
}
```

As a plan author, you might want to ensure the `sql` plan runs the
`postgresql::sql` task on each target with the correct user and password
that are listed under each target's `vars` field.

To ensure the `postgresql::sql` task is available to the tests, add the
`puppetlabs/postgresql` module to the `.fixtures.yml` file in the module's root
directory.

```yaml
# .fixtures.yml
fixtures:
  forge_modules:
    postgresql:
      repo: "puppetlabs/postgresql"
      ref: "7.0.2"
```

Because the plan uses the target `vars` field, the tests must include an
inventory. You can override the default inventory in `BoltSpec` using the
`inventory_data` function.

When testing plans that include the `run_task_with()` function, you should
include stubs or mocks for each target the task is expected to run on.
For example, if you pass two targets to the `run_task_with()` function:

```puppet
run_task_with('task', ['target1', 'target2'])
```

And your task includes a single assertion that the task is run on both
targets:

```ruby
expect_task('task').with_targets(['target1', 'target2'])
```

Then the assertion will never be satisfied. This is because BoltSpec executes a
separate task run for each target passed to the `run_task_with()` function. Both
of the following assertions, however, would be satisfied:

```ruby
# Assert that the task is run twice
expect_task('task').be_called_times(2)
```

```ruby
# Assert that the task is run on each target
expect_task('task').with_targets('target1')
expect_task('task').with_targets('target2')
```

Save the following test to `sql/spec/plans/init_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'sql' do
  include BoltSpec::Plans

  # Inventory that is loaded by Bolt with targets that can be referenced
  # by name in stubs and mocks
  def inventory_data
    {
      'targets' => [
        {
          'name' => 'target1',
          'vars' => {
            'postgres_password' => 'Bolt!',
            'postgres_user'     => 'bolt'
          }
        },
        {
          'name' => 'target2',
          'vars' => {
            'postgres_password' => 'Puppet!',
            'postgres_user'     => 'puppet'
          }
        }
      ]
    }
  end

  let(:sql) { 'select * from examples' }

  # Configure Puppet and Bolt before running the test
  before(:all) do
    BoltSpec::Plans.init
  end

  it 'passes target-specific parameters to the postgresql::sql task' do
    expect_task('postgresql::sql')
      .with_targets('target1')
      .with_params('password' => 'Bolt!', 'user' => 'bolt', 'sql' => sql)

    expect_task('postgresql::sql')
      .with_targets('target2')
      .with_params('password' => 'Puppet!', 'user' => 'puppet', 'sql' => sql)

    run_plan('sql', 'sql' => sql, 'targets' => 'all')
  end
end
```

Run the tests:

```shell
pdk bundle exec rake spec
```

📖 **Related information**

- For more information on the available mocks and stubs, see the [BoltSpec
  reference](boltspec_reference.md).
