# BoltSpec reference

The `BoltSpec` helper library includes several functions to help write unit
tests for plans. For more information about writing unit tests for plans, and
how to use these functions, see [Testing plans](testing_plans.md).

## Execution modes

Plans often execute sub-plans with the `run_plan` function to build complex
workflows. When testing these plans, it might be helpful to execute any
sub-plans as well without needing to stub or mock the plan. To support this,
`BoltSpec` offers two different execution modes:

### `execute_any_plan`

  **Default mode.** When running in this mode, `BoltSpec` runs any plan invoked
  with the`run_plan` function as long as that plan is not stubbed or mocked. If
  a plan is stubbed or mocked while running in this mode, `BoltSpec` honors the
  stub or mock and does not execute the plan.

  ```ruby
  it 'executes a task' do
    execute_any_plan

    # Test code . . .
  end
  ```

### `execute_no_plan`

  If a test is run in `execute_no_plan` mode, `BoltSpec` does not run any plan
  that is invoked with the `run_plan` function. If `BoltSpec` encounters a
  `run_plan` function and it is not stubbed or mocked, the test fails. This mode
  is useful for ensuring that your plan is not running any unexpected sub-plans.
  Test authors should stub or mock all sub-plans that might be invoked during a
  test.

  ```ruby
  it 'executes a task' do
    execute_no_plan

    # Test code . . .
  end
  ```

## Mocks

Mocks serve two purposes when you are writing tests for your plans: they allow
assertions about plan functions invoked during a plan run and also allow you
to set their return values. For example, you might use a mock to make an
assertion that the `run_task` function is invoked exactly one time during a test
and have the mocked function return `{ 'stdout' => 'Task was successful!' }`.

### `expect_command`

The `expect_command` function mocks the [`run_command`
function](plan_functions.md#run-command). It accepts a single parameter: a
command.

```ruby
expect_command('whoami')
```

The `expect_command` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the command is not run exactly _number_ times.

  ```ruby
  expect_command('whoami').be_called_times(1)
  ```

- `not_be_called`

  The test fails if the command is run.

  ```ruby
  expect_command('whoami').not_be_called
  ```

- `with_targets(targets)`

  The target or list of targets that the command must be run on. The test fails
  if the command is not run on the list of targets.

  ```ruby
  expect_command('whoami').with_targets(['target1', 'target2', 'target3'])
  ```

- `with_params(parameters)`

  The [options](plan_functions.md#run-command) that must be passed to the
  `run_command` function. The test fails if the command is not run with the set
  of options.

  ```ruby
  expect_command('whoami').with_params({ '_run_as' => 'root' })
  ```

- `always_return(value)`

  Sets the value for each target's `Result` when the command is run. Returns a
  `Bolt::ResultSet` object. Only accepts `stderr` and `stdout` keys.

  ```ruby
  expect_command('whoami').always_return({ 'stdout' => 'BoltyMcBoltface' })
  ```

- `return_for_targets(targets_to_values)`

  Sets the value for each target's `Result` when the command is run. Accepts a
  hash of key-value pairs where each key is a target and the value is the value
  for that target's `Result`. Values can only have `stderr` and `stdout` keys.

  ```ruby
  expect_command('whoami').return_for_targets(
    'target1' => { 'stdout' => 'BoltyMcBoltFace' },
    'target2' => { 'stdout' => 'Robert' },
    'target3' => { 'stdout' => 'Bobert' }
  )
  ```

- `return(&block) { |targets, command, params| ... }`

  Invokes a block to construct the `ResultSet` returned by the `run_command`
  function.

  ```ruby
  expect_command('whoami').return do |targets, command, params|
    results = targets.map do |target|
      Bolt::Result.new(target, value: { 'stdout' => 'BoltyMcBoltface' })
    end

    Bolt::ResultSet.new(results)
  end
  ```

- `error_with(error)`

  Sets the error hash for each target's `Result` when the command is run. Returns a
  `Bolt::ResultSet` object.

  ```ruby
  expect_command('whoami').error_with('msg' => 'sh: command not found: whoami')
  ```

### `expect_download`

The `expect_download` function mocks the [`download_file`
function](plan_functions.md#download-file). It accepts a single parameter: the
path to a remote file to download.

```ruby
expect_download('/var/log/kern.log')
```

The `expect_download` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the file is not downloaded exactly _number_ times.

  ```ruby
  expect_download('/var/log/kern.log').be_called_times(1)
  ```

- `not_be_called`

  The test fails if the file is downloaded.

  ```ruby
  expect_download('/var/log/kern.log').not_be_called
  ```

- `with_targets(targets)`

  The target or list of targets that the file must be downloaded from. The test
  fails if the file is not downloaded from the list of targets.

  ```ruby
  expect_download('/var/log/kern.log').with_targets(['target1', 'target2', 'target3'])
  ```

- `with_params(parameters)`

  The [options](plan_functions.md#download-file) that must be passed to the
  `download_file` function. The test fails if the file is not downloaded with
  the set of options.

  ```ruby
  expect_download('/var/log/kern.log').with_params({ '_run_as' => 'root' })
  ```

- `with_destination(destination)`

  The destination path that the file is downloaded to. The test fails if the
  file is not downloaded to the location.

  ```ruby
  expect_download('/var/log/kern.log').with_destination('kernel')
  ```

- `return(&block) { |targets, source, destination, params| ... }`

  Invokes a block to construct the `ResultSet` returned by the `download_file`
  function.

  ```ruby
  expect_download('/var/log/kern.log').return do |targets, source, destination, params|
    results = targets.map do |target|
      Bolt::Result.new(target, value: { 'path' => File.join(destination, source) })
    end

    Bolt::ResultSet.new(results)
  end
  ```

- `error_with(error)`

  Sets the error hash for each target's `Result` when the file is downloaded.
  Returns a `Bolt::ResultSet` object.

  ```ruby
  expect_download('/var/log/kern.log').error_with('msg' => 'File not found')
  ```

### `expect_out_message`

The `expect_out_message` function mocks the [`out::message` function](plan_functions.md#out::message). It does not accept any parameters.

```ruby
expect_out_message
```

The `expect_out_message` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if `out::message` is not invoked exactly _number_ times.

  ```ruby
  expect_out_message.be_called_times(3)
  ```

- `not_be_called`

  The test fails if `out::message` is invoked.

  ```ruby
  expect_out_message.not_be_called
  ```

- `with_params(params)`

  The message that must be passed to the `out::message` function. The test fails if
  the function is not invoked with the message.

  ```ruby
  expect_out_message.with_params('This is not the example you are looking for.')
  ```

### `expect_out_verbose`

The `expect_out_verbose` function mocks the [`out::verbose` function](plan_functions.md#outverbose). It does not accept any parameters.

```ruby
expect_out_verbose
```

The `expect_out_verbose` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if `out::verbose` is not invoked exactly _number_ times.

  ```ruby
  expect_out_verbose.be_called_times(3)
  ```

- `not_be_called`

  The test fails if `out::verbose` is invoked.

  ```ruby
  expect_out_verbose.not_be_called
  ```

- `with_params(params)`

  The message that must be passed to the `out::verbose` function. The test fails if
  the function is not invoked with the message.

  ```ruby
  expect_out_verbose.with_params('This is not the example you are looking for.')
  ```


### `expect_plan`

The `expect_plan` function mocks the [`run_plan` function](plan_functions.md#run-plan).
It accepts a single parameter: the name of a plan.

```ruby
expect_plan('count')
```

The `expect_plan` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the plan is not run exactly _number_ times.

  ```ruby
  expect_plan('count').be_called_times(3)
  ```

- `not_be_called`

  The test fails if the plan is run.

  ```ruby
  expect_plan('count').not_be_called
  ```

- `with_params(parameters)`

  The parameters and [options](plan_functions.md#run-plan) that must be passed
  to the `run_plan` function. The test fails if the plan is not run with the set
  of parameters and options.

  ```ruby
  expect_plan('count').with_params({ 'fruit' => 'apple', '_run_as' => 'root' })
  ```

- `always_return(value)`

  Sets the value for the `PlanResult` object returned by the plan. The
  `PlanResult` object returned by this modifier always has a `success` status.

  ```ruby
  expect_plan('count').always_return(222)
  ```

- `return(&block) { |plan, params| ... }`

  Invokes a block to construct the `PlanResult` returned by the `run_plan`
  function.

  ```ruby
  expect_plan('count').return do |plan, params|
    Bolt::PlanResult.new(100, 'success')
  end
  ```

- `error_with(error)`

  Sets the value for the `PlanResult` object returned by the plan. The
  `PlanResult` object returned by this modifier always has a `failure` status.

  ```ruby
  expect_plan('count').error_with('Too many apples, buffer overflow!')
  ```

### `expect_script`

The `expect_script` function mocks the [`run_script`
function](plan_functions.md#run-script). It accepts a single parameter: the path
to a script.

```ruby
expect_script('configure.sh')
```

The `expect_script` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the script is not run exactly _number_ times.

  ```ruby
  expect_script('configure.sh').be_called_times(1)
  ```

- `not_be_called`

  The test fails if the script is run.

  ```ruby
  expect_script('configure.sh').not_be_called
  ```

- `with_targets(targets)`

  The target or list of targets that the script must be run on. The test fails
  if the script is not run on the list of targets.

  ```ruby
  expect_script('configure.sh').with_targets(['target1', 'target2', 'target3'])
  ```

- `with_params(parameters)`

  The [options](plan_functions.md#run-script) that must be passed to the
  `run_script` function. The test fails if the script is not run with the set of
  options.

  ```ruby
  expect_script('configure.sh').with_params({ 'arguments' => ['/u', 'Administrator'] })
  ```

- `always_return(value)`

  Sets the value for each target's `Result` when the script is run. Returns a
  `Bolt::ResultSet` object. Values only accept `stderr` and `stdout` keys.

  ```ruby
  expect_script('configure.sh').always_return({ 'stdout' => 'success' })
  ```

- `return_for_targets(targets_to_values)`

  Sets the value for each target's `Result` when the script is run. Accepts a
  hash of key-value pairs where each key is a target and the value is the value
  for that target's `Result`. Values only accept `stderr` and `stdout` keys.

  ```ruby
  expect_script('configure.sh').return_for_targets(
    'target1' => { 'stdout' => 'success' },
    'target2' => { 'stdout' => 'failure' }
  )
  ```

- `return(&block) { |targets, script, params| ... }`

  Invokes a block to construct the `ResultSet` returned by the `run_script`
  function.

  ```ruby
  expect_script('configure.sh').return do |targets, script, params|
    results = targets.map do |target|
      Bolt::Result.new(target, value: { 'stdout' => 'success' })
    end

    Bolt::ResultSet.new(results)
  end
  ```

- `error_with(error)`

  Sets the error hash for each target's `Result` when the script is run. Returns a
  `Bolt::ResultSet` object.

  ```ruby
  expect_script('configure.sh').error_with('msg' => 'sh: command not found: apt-get')
  ```

### `expect_task`

The `expect_task` functions mocks the [`run_task`
function](plan_functions.md#run-task). It accepts a single parameter: the name
of a task.

```ruby
expect_task('pet_dog')
```

The `expect_task` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the task is not run exactly _number_ times.

  ```ruby
  expect_task('pet_dog').be_called_times(3)
  ```

- `not_be_called`

  The test fails if the task is run.

  ```ruby
  expect_task('pet_dog').not_be_called
  ```

- `with_targets(targets)`

  The target or list of targets that the task must be run on. The test fails if
  the task is not run on the list of targets.

  ```ruby
  expect_task('pet_dog').with_targets(['target1', 'target2', 'target3'])
  ```

- `with_params(parameters)`

  The parameters and [options](plan_functions.md#run-script) that must be passed
  to the `run_task` function. The test fails if the task is not run with the set
  of parameters and options.

  ```ruby
  expect_task('pet_dog').with_params({ 'breed' => 'german shepherd' })
  ```

- `always_return(value)`

  Sets the value for each target's `Result` when the task is run. Returns a
  `Bolt::ResultSet` object.

  ```ruby
  expect_task('pet_dog').always_return({ 'happy' => true })
  ```

- `return_for_targets(targets_to_values)`

  Sets the value for each target's `Result` when the task is run. Accepts a
  hash of key-value pairs where each key is a target and the value is the value
  for that target's `Result`.

  ```ruby
  expect_task('pet_dog').return_for_targets(
    'target1' => { 'happy' => true },
    'target2' => { 'happy' => false }
  )
  ```

- `return(&block) { |targets, task, params| ... }`

  Invokes a block to construct the `ResultSet` returned by the `run_task`
  function.

  ```ruby
  expect_task('pet_dog').return do |targets, task, params|
    results = targets.map do |target|
      Bolt::Result.new(target, value: { 'happy' => true })
    end

    Bolt::ResultSet.new(results)
  end
  ```

- `error_with(error)`

  Sets the error hash for each target's `Result` when the task is run. Returns a
  `Bolt::ResultSet` object.

  ```ruby
  expect_task('pet_dog').error_with('msg' => 'There are no German Shepherds to pet.')
  ```

### `expect_upload`

The `expect_upload` function mocks the [`upload_file`
function](plan_functions.md#upload-file). It accepts a single parameter: the
path to a local file to upload.

```ruby
expect_upload('sshd_config')
```

The `expect_upload` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the file is not uploaded exactly _number_ times.

  ```ruby
  expect_upload('sshd_config').be_called_times(1)
  ```

- `not_be_called`

  The test fails if the file is uploaded.

  ```ruby
  expect_upload('sshd_config').not_be_called
  ```

- `with_targets(targets)`

  The target or list of targets that the file must be uploaded to. The test
  fails if the file is not uploaded to the list of targets.

  ```ruby
  expect_upload('sshd_config').with_targets(['target1', 'target2', 'target3'])
  ```

- `with_params(parameters)`

  The [options](plan_functions.md#upload-file) that must be passed to the
  `upload_file` function. The test fails if the file is not uploaded with the
  set of options.

  ```ruby
  expect_upload('sshd_config').with_params({ '_run_as' => 'root' })
  ```

- `with_destination(destination)`

  The destination path that the file must be uploaded to. The test fails if the
  file is not uploaded to the location.

  ```ruby
  expect_upload('sshd_config').with_destination('/etc/ssh/sshd_config')
  ```

- `return(&block) { |targets, source, destination, params| ... }`

  Invokes a block to construct the `ResultSet` returned by the `upload_file`
  function.

  ```ruby
  expect_upload('sshd_config').return do |targets, source, destination, params|
    results = targets.map do |target|
      Bolt::Result.new(target, value: { 'path' => File.join(destination, source) })
    end

    Bolt::ResultSet.new(results)
  end
  ```

- `error_with(error)`

  Sets the error hash for each target's `Result` when the file is uploaded.
  Returns a `Bolt::ResultSet` object.

  ```ruby
  expect_upload('sshd_config').error_with('msg' => 'Not authorized')
  ```

## Stubs

Stubs serve two purposes when you are writing tests for your plans: they allow
plan functions to be invoked during a plan run and also allow you to set
their return values. For example, you might use a stub to allow the `run_task`
function to be invoked any number of times during a test.

### `allow_apply`

The `allow_apply` function stubs the [`apply`
function](plan_functions.md#apply). It does not accept any parameters or
modifiers. Using the `allow_apply` stub only allows you to invoke the `apply`
function in a plan.

### `allow_apply_prep`

The `allow_apply_prep` function stubs the [`apply_prep`
function](plan_functions.md#apply-prep). It does not accept any parameters or
modifiers. Using the `allow_apply_prep` stub only allows you to invoke the
`apply_prep` function in a plan.

### `allow_command`

The `allow_command` function stubs the [`run_command`
function](plan_functions.md#run-command). It accepts a single parameter: a
command.

```ruby
allow_command('whoami')
```

The `allow_command` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the command is run more than _number_ of times.

  ```ruby
  allow_command('whoami').be_called_times(3)
  ```

- `not_be_called`

  The test fails if the command is run.

  ```ruby
  allow_command('whoami').not_be_called
  ```

- `with_targets(targets)`

  The target or list of targets that the command can be run on. The test fails
  if the command is run on a different list of targets.

  ```ruby
  allow_command('whoami').with_targets(['target1', 'target2', 'target3'])
  ```

- `with_params(parameters)`

  The [options](plan_functions.md#run-command) that can be passed to the
  `run_command` function. The test fails if the command is run with a different
  set of options.

  ```ruby
  allow_command('whoami').with_params({ '_run_as' => 'root' })
  ```

- `always_return(value)`

  Sets the value for each target's `Result` when the command is run. Returns a
  `Bolt::ResultSet` object. Only accepts `stderr` and `stdout` keys.

  ```ruby
  allow_command('whoami').always_return({ 'stdout' => 'BoltyMcBoltface' })
  ```

- `return_for_targets(targets_to_values)`

  Sets the value for each target's `Result` when the command is run. Accepts a
  hash of key-value pairs where each key is a target and the value is the value
  for that target's `Result`. Values can only have `stderr` and `stdout` keys.

  ```ruby
  allow_command('whoami').return_for_targets(
    'target1' => { 'stdout' => 'BoltyMcBoltFace' },
    'target2' => { 'stdout' => 'Robert' },
    'target3' => { 'stdout' => 'Bobert' }
  )
  ```

- `return(&block) { |targets, command, params| ... }`

  Invokes a block to construct the `ResultSet` returned by the `run_command`
  function.

  ```ruby
  allow_command('whoami').return do |targets, command, params|
    results = targets.map do |target|
      Bolt::Result.new(target, value: { 'stdout' => 'BoltyMcBoltface' })
    end

    Bolt::ResultSet.new(results)
  end
  ```

- `error_with(error)`

  Sets the error hash for each target's `Result` when the command is run. Returns a
  `Bolt::ResultSet` object.

  ```ruby
  allow_command('whoami').error_with('msg' => 'sh: command not found: whoami')
  ```

### `allow_download`

The `allow_download` function stubs the [`download_file`
function](plan_functions.md#download-file). It accepts a single parameter: the
path to a remote file to download.

```ruby
allow_download('/var/log/kern.log')
```

The `allow_download` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the file is downloaded more than _number_ times.

  ```ruby
  allow_download('/var/log/kern.log').be_called_times(1)
  ```

- `not_be_called`

  The test fails if the file is downloaded.

  ```ruby
  allow_download('/var/log/kern.log').not_be_called
  ```

- `with_targets(targets)`

  The target or list of targets that the file can be downloaded from. The test
  fails if the file is downloaded from a different list of targets.

  ```ruby
  allow_download('/var/log/kern.log').with_targets(['target1', 'target2', 'target3'])
  ```

- `with_params(parameters)`

  The [options](plan_functions.md#download-file) that can be passed to the
  `download_file` function. The test fails if the file is downloaded with a
  different set of options.

  ```ruby
  allow_download('/var/log/kern.log').with_params({ '_run_as' => 'root' })
  ```

- `with_destination(destination)`

  The destination path that the file is downloaded to. The test fails if the
  file is downloaded to a different location.

  ```ruby
  allow_download('/var/log/kern.log').with_destination('kernel')
  ```

- `return(&block) { |targets, source, destination, params| ... }`

  Invokes a block to construct the `ResultSet` returned by the `download_file`
  function.

  ```ruby
  allow_download('/var/log/kern.log').return do |targets, source, destination, params|
    results = targets.map do |target|
      Bolt::Result.new(target, value: { 'path' => File.join(destination, source) })
    end

    Bolt::ResultSet.new(results)
  end
  ```

- `error_with(error)`

  Sets the error hash for each target's `Result` when the file is downloaded.
  Returns a `Bolt::ResultSet` object.

  ```ruby
  allow_download('/var/log/kern.log').error_with('msg' => 'File not found')
  ```

### `allow_out_message`

The `allow_out_message` function stubs the [`out::message` function](plan_functions.md#out::message). It does not accept any parameters.

```ruby
allow_out_message
```

The `allow_out_message` function accepts the following stub modifiers:

- `be_called_times(number)`

  The test fails if `out::message` is invoked more than _number_ times.

  ```ruby
  allow_out_message.be_called_times(3)
  ```

- `not_be_called`

  The test fails if `out::message` is invoked.

  ```ruby
  allow_out_message.not_be_called
  ```

- `with_params(params)`

  The message that can be passed to the `out::message` function. The test fails if
  the function is invoked with a different message.

  ```ruby
  allow_out_message.with_params('This is not the example you are looking for.')
  ```

### `allow_out_verbose`

The `allow_out_verbose` function stubs the [`out::verbose` function](plan_functions.md#outverbose). It does not accept any parameters.

```ruby
allow_out_verbose
```

The `allow_out_verbose` function accepts the following stub modifiers:

- `be_called_times(number)`

  The test fails if `out::verbose` is invoked more than _number_ times.

  ```ruby
  allow_out_verbose.be_called_times(3)
  ```

- `not_be_called`

  The test fails if `out::verbose` is invoked.

  ```ruby
  allow_out_verbose.not_be_called
  ```

- `with_params(params)`

  The message that can be passed to the `out::verbose` function. The test fails if
  the function is invoked with a different message.

  ```ruby
  allow_out_verbose.with_params('This is not the example you are looking for.')
  ```

### `allow_plan`

The `allow_plan` function stubs the [`run_plan`
function](plan_functions.md#run-plan). It accepts a single parameter: the name
of a plan.

```ruby
allow_plan('count')
```

The `allow_plan` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the plan is run more than _number_ times.

  ```ruby
  allow_plan('count').be_called_times(3)
  ```

- `not_be_called`

  The test fails if the plan is run.

  ```ruby
  allow_plan('count').not_be_called
  ```

- `with_params(parameters)`

  The parameters and [options](plan_functions.md#run-plan) that can be passed to
  the `run_plan` function. The test fails if the plan is run with a different
  set of parameters and options.

  ```ruby
  allow_plan('count').with_params({ 'fruit' => 'apple', '_run_as' => 'root' })
  ```

- `always_return(value)`

  Sets the value for the `PlanResult` object returned by the plan. The
  `PlanResult` object returned by this modifier always has a `success` status.

  ```ruby
  allow_plan('count').always_return(222)
  ```

- `return(&block) { |plan, params| ... }`

  Invokes a block to construct the `PlanResult` returned by the `run_plan`
  function.

  ```ruby
  allow_plan('count').return do |plan, params|
    Bolt::PlanResult.new(100, 'success')
  end
  ```

- `error_with(error)`

  Sets the value for the `PlanResult` object returned by the plan. The
  `PlanResult` object returned by this modifier always has a `failure` status.

  ```ruby
  allow_plan('count').error_with('Too many apples, buffer overflow!')
  ```

### `allow_script`

The `allow_script` function stubs the [`run_script`
function](plan_functions.md#run-script). It accepts a single parameter: the path
to a script.

```ruby
allow_script('configure.sh')
```

The `allow_script` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the script is run more than _number_ times.

  ```ruby
  allow_script('configure.sh').be_called_times(3)
  ```

- `not_be_called`

  The test fails if the script is run.

  ```ruby
  allow_script('configure.sh').not_be_called
  ```

- `with_targets(targets)`

  The target or list of targets that the script can be run on. The test fails if
  the script is run on a different list of targets.

  ```ruby
  allow_script('configure.sh').with_targets(['target1', 'target2', 'target3'])
  ```

- `with_params(parameters)`

  The [options](plan_functions.md#run-script) that can be passed to the
  `run_script` function. The test fails if the script is run with a different
  set of options.

  ```ruby
  allow_script('configure.sh').with_params({ 'arguments' => ['/u', 'Administrator'] })
  ```

- `always_return(value)`

  Sets the value for each target's `Result` when the script is run. Returns a
  `Bolt::ResultSet` object. Values only accept `stderr` and `stdout` keys.

  ```ruby
  allow_script('configure.sh').always_return({ 'stdout' => 'success' })
  ```

- `return_for_targets(targets_to_values)`

  Sets the value for each target's `Result` when the script is run. Accepts a
  hash of key-value pairs where each key is a target and the value is the value
  for that target's `Result`. Values only accept `stderr` and `stdout` keys.

  ```ruby
  allow_script('configure.sh').return_for_targets(
    'target1' => { 'stdout' => 'success' },
    'target2' => { 'stdout' => 'failure' }
  )
  ```

- `return(&block) { |targets, script, params| ... }`

  Invokes a block to construct the `ResultSet` returned by the `run_script`
  function.

  ```ruby
  allow_script('configure.sh').return do |targets, script, params|
    results = targets.map do |target|
      Bolt::Result.new(target, value: { 'stdout' => 'success' })
    end

    Bolt::ResultSet.new(results)
  end
  ```

- `error_with(error)`

  Sets the error hash for each target's `Result` when the script is run. Returns a
  `Bolt::ResultSet` object.

  ```ruby
  allow_script('configure.sh').error_with('msg' => 'sh: command not found: apt-get')
  ```

### `allow_task`

The `allow_task` function stubs the [`run_task`
function](plan_functions.md#run-task). It accepts a single parameter: the name
of a task.

```ruby
allow_task('pet_dog')
```

The `allow_task` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the task is run more than _number_ times.

  ```ruby
  allow_task('pet_dog').be_called_times(3)
  ```

- `not_be_called`

  The test fails if the task is run.

  ```ruby
  allow_task('pet_dog').not_be_called
  ```

- `with_targets(targets)`

  The target or list of targets that the task can be run on. The test fails if
  the task is run on a different list of targets.

  ```ruby
  allow_task('pet_dog').with_targets(['target1', 'target2', 'target3'])
  ```

- `with_params(parameters)`

  The parameters and [options](plan_functions.md#run-script) that can be passed to the
  `run_task` function. The test fails if the task is run with a different
  set of parameters and options.

  ```ruby
  allow_task('pet_dog').with_params({ 'breed' => 'german shepherd' })
  ```

- `always_return(value)`

  Sets the value for each target's `Result` when the task is run. Returns a
  `Bolt::ResultSet` object.

  ```ruby
  allow_task('pet_dog').always_return({ 'happy' => true })
  ```

- `return_for_targets(targets_to_values)`

  Sets the value for each target's `Result` when the task is run. Accepts a
  hash of key-value pairs where each key is a target and the value is the value
  for that target's `Result`.

  ```ruby
  allow_task('pet_dog').return_for_targets(
    'target1' => { 'happy' => true },
    'target2' => { 'happy' => false }
  )
  ```

- `return(&block) { |targets, task, params| ... }`

  Invokes a block to construct the `ResultSet` returned by the `run_task`
  function.

  ```ruby
  allow_task('pet_dog').return do |targets, task, params|
    results = targets.map do |target|
      Bolt::Result.new(target, value: { 'happy' => true })
    end

    Bolt::ResultSet.new(results)
  end
  ```

- `error_with(error)`

  Sets the error hash for each target's `Result` when the task is run. Returns a
  `Bolt::ResultSet` object.

  ```ruby
  allow_task('pet_dog').error_with('msg' => 'There are no German Shepherds to pet.')
  ```

### `allow_upload`

The `allow_upload` function stubs the [`upload_file`
function](plan_functions.md#upload-file). It accepts a single parameter: the
path to a local file to upload.

```ruby
allow_upload('sshd_config')
```

The `allow_upload` function accepts the following modifiers:

- `be_called_times(number)`

  The test fails if the file is uploaded more than _number_ times.

  ```ruby
  allow_upload('sshd_config').be_called_times(1)
  ```

- `not_be_called`

  The test fails if the file is uploaded.

  ```ruby
  allow_upload('sshd_config').not_be_called
  ```

- `with_targets(targets)`

  The target or list of targets that the file can be uploaded to. The test
  fails if the file is uploaded to a different list of targets.

  ```ruby
  allow_upload('sshd_config').with_targets(['target1', 'target2', 'target3'])
  ```

- `with_params(parameters)`

  The [options](plan_functions.md#upload-file) that can be passed to the
  `upload_file` function. The test fails if the file is uploaded with a
  different set of  options.

  ```ruby
  allow_upload('sshd_config').with_params({ '_run_as' => 'root' })
  ```

- `with_destination(destination)`

  The destination path that the file is uploaded to. The test fails if the
  file is uploaded to a different location.

  ```ruby
  allow_upload('sshd_config').with_destination('/etc/ssh/sshd_config')
  ```

- `return(&block) { |targets, source, destination, params| ... }`

  Invokes a block to construct the `ResultSet` returned by the `upload_file`
  function.

  ```ruby
  allow_upload('sshd_config').return do |targets, source, destination, params|
    results = targets.map do |target|
      Bolt::Result.new(target, value: { 'path' => File.join(destination, source) })
    end

    Bolt::ResultSet.new(results)
  end
  ```

- `error_with(error)`

  Sets the error hash for each target's `Result` when the file is uploaded.
  Returns a `Bolt::ResultSet` object.

  ```ruby
  allow_upload('sshd_config').error_with('msg' => 'Not authorized')
  ```

📖 **Related information**

- For more information on using `BoltSpec`, see [Testing plans](testing_plans.md).
