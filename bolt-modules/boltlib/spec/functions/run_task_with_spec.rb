# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/result'
require 'bolt/result_set'
require 'puppet/pops/types/p_sensitive_type'

class TaskTypeMatcher < Mocha::ParameterMatchers::Equals
  def initialize(executable, input_method)
    super(nil)
    @executable = Regexp.new(executable)
    @input_method = input_method
  end

  def matches?(available_parameters)
    other = available_parameters.shift
    @executable =~ other.files.first['path'] && @input_method == other.metadata['input_method']
  end
end

describe 'run_task_with' do
  include PuppetlabsSpec::Fixtures
  let(:executor)      { Bolt::Executor.new }
  let(:inventory)     { Bolt::Inventory.empty }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    executor.stubs(:noop).returns(false)

    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  def mock_task(executable, input_method)
    TaskTypeMatcher.new(executable, input_method)
  end

  context 'it calls bolt executor run_task_with' do
    let(:hostname)       { 'a.b.com' }
    let(:hostname2)      { 'x.y.com' }
    let(:hosts)          { [hostname, hostname2] }
    let(:message)        { 'the message' }
    let(:target)         { inventory.get_target(hostname) }
    let(:target2)        { inventory.get_target(hostname2) }
    let(:targets)        { [target, target2] }
    let(:target_mapping) { { target => task_params, target2 => task_params } }
    let(:result)         { Bolt::Result.new(target, value: { '_output' => message }) }
    let(:result2)        { Bolt::Result.new(target2, value: { '_output' => message }) }
    let(:result_set)     { Bolt::ResultSet.new([result]) }
    let(:tasks_root)     { File.expand_path(fixtures('modules', 'test', 'tasks')) }
    let(:task_params)    { { 'message' => message } }

    context 'without tasks enabled' do
      let(:tasks_enabled) { false }

      it 'fails and reports that run_task is not available' do
        is_expected.to run
          .with_params('Test::Echo', hostname)
          .with_lambda { |_| {} }
          .and_raise_error(/Plan language function 'run_task_with' cannot be used/)
      end
    end

    it 'maps parameters to targets' do
      executable = File.join(tasks_root, 'meta.sh')

      target_mapping = {
        target  => { 'message' => target.safe_name },
        target2 => { 'message' => target2.safe_name }
      }

      executor.expects(:run_task_with)
              .with(target_mapping, mock_task(executable, 'environment'), {})
              .returns(result_set)

      inventory.expects(:get_targets).with(hosts).returns(targets)

      is_expected.to(run
        .with_params('Test::Meta', hosts)
        .with_lambda { |t| { 'message' => t.safe_name } })
    end

    it '_run_as is passed to the executor' do
      executable = File.join(tasks_root, 'meta.sh')

      executor.expects(:run_task_with)
              .with(target_mapping, mock_task(executable, 'environment'), run_as: 'root')
              .returns(result_set)

      inventory.expects(:get_targets).with(hosts).returns(targets)

      is_expected.to(run
        .with_params('Test::Meta', hosts, { '_run_as' => 'root' })
        .with_lambda { |_| task_params }
        .and_return(result_set))
    end

    it 'uses the default if a parameter is not specified' do
      executable = File.join(tasks_root, 'params.sh')

      args = {
        'mandatory_string'  => 'str',
        'mandatory_integer' => 10,
        'mandatory_boolean' => true
      }

      defaults = {
        'default_string'          => 'hello',
        'optional_default_string' => 'goodbye'
      }

      target_mapping = {
        target  => args.merge(defaults),
        target2 => args.merge(defaults)
      }

      executor.expects(:run_task_with).with(target_mapping, mock_task(executable, 'stdin'), {}).returns(result_set)
      inventory.expects(:get_targets).with(hosts).returns(targets)

      is_expected.to(run
        .with_params('Test::Params', hosts)
        .with_lambda { |_| args })
    end

    it 'does not use the default if a parameter is specified' do
      executable = File.join(tasks_root, 'params.sh')

      args = {
        'mandatory_string'        => 'str',
        'mandatory_integer'       => 10,
        'mandatory_boolean'       => true,
        'default_string'          => 'something',
        'optional_default_string' => 'something else'
      }

      target_mapping = { target => args, target2 => args }

      executor.expects(:run_task_with).with(target_mapping, mock_task(executable, 'stdin'), {}).returns(result_set)
      inventory.expects(:get_targets).with(hosts).returns(targets)

      is_expected.to(run
        .with_params('Test::Params', hosts)
        .with_lambda { |_| args })
    end

    it 'uses the default if a parameter is specified as undef' do
      executable = File.join(tasks_root, 'undef.sh')
      args = {
        'undef_default'    => nil,
        'undef_no_default' => nil
      }
      expected_args = {
        'undef_default'    => 'foo',
        'undef_no_default' => nil
      }
      target_mapping = {
        target  => expected_args,
        target2 => expected_args
      }

      executor.expects(:run_task_with).with(target_mapping, mock_task(executable, 'environment'), {})
              .returns(result_set)
      inventory.expects(:get_targets).with(hosts).returns(targets)

      is_expected.to(run
        .with_params('test::undef', hosts)
        .with_lambda { |_| args })
    end

    it 'does not invoke Bolt when target list is empty' do
      executor.expects(:run_task).never
      inventory.expects(:get_targets).with([]).returns([])

      is_expected.to(run
        .with_params('Test::Yes', [])
        .with_lambda { |_| {} }
        .and_return(Bolt::ResultSet.new([])))
    end

    it 'reports the function call and task name to analytics' do
      executor.expects(:report_function_call).with('run_task_with')
      executor.expects(:report_bundled_content).with('Task', 'Test::Echo').once
      executable = File.join(tasks_root, 'echo.sh')

      executor.expects(:run_task_with).with(target_mapping, mock_task(executable, nil), {}).returns(result_set)
      inventory.expects(:get_targets).with(hosts).returns(targets)

      is_expected.to(run
        .with_params('Test::Echo', hosts)
        .with_lambda { |_| task_params }
        .and_return(result_set))
    end

    context 'with description' do
      let(:message) { 'test message' }

      it 'passes the description through' do
        executor.expects(:run_task_with).with(target_mapping, anything, description: message).returns(result_set)
        inventory.expects(:get_targets).with(hosts).returns(targets)

        is_expected.to(run
          .with_params('test::yes', hosts, message)
          .with_lambda { |_| task_params })
      end
    end

    context 'without description' do
      it 'ignores description if options are passed' do
        executor.expects(:run_task_with).with(target_mapping, anything, {}).returns(result_set)
        inventory.expects(:get_targets).with(hosts).returns(targets)

        is_expected.to(run
          .with_params('test::yes', hosts, {})
          .with_lambda { |_| task_params })
      end

      it 'ignores description if no parameters are passed' do
        executor.expects(:run_task_with).with(target_mapping, anything, {}).returns(result_set)
        inventory.expects(:get_targets).with(hosts).returns(targets)

        is_expected.to(run
          .with_params('test::yes', hosts)
          .with_lambda { |_| task_params })
      end
    end

    context 'with multiple destinations' do
      let(:result_set) { Bolt::ResultSet.new([result, result2]) }

      it 'targets can be specified as repeated nested arrays and strings and combine into one list of targets' do
        executable = File.join(tasks_root, 'meta.sh')

        executor.expects(:run_task_with)
                .with(target_mapping, mock_task(executable, 'environment'), {})
                .returns(result_set)

        inventory.expects(:get_targets).with([hostname, [[hostname2]], []]).returns(targets)

        is_expected.to(run
          .with_params('Test::Meta', [hostname, [[hostname2]], []])
          .with_lambda { |_| task_params }
          .and_return(result_set))
      end

      it 'targets can be specified as repeated nested arrays and Targets and combine into one list of targets' do
        executable = File.join(tasks_root, 'meta.sh')

        executor.expects(:run_task_with)
                .with(target_mapping, mock_task(executable, 'environment'), {})
                .returns(result_set)

        inventory.expects(:get_targets).with([target, [[target2]], []]).returns(targets)

        is_expected.to(run
          .with_params('Test::Meta', [target, [[target2]], []])
          .with_lambda { |_| task_params }
          .and_return(result_set))
      end

      context 'when a command fails on one target' do
        let(:failresult) { Bolt::Result.new(target2, error: { 'msg' => 'oops' }) }
        let(:result_set) { Bolt::ResultSet.new([result, failresult]) }

        it 'errors by default' do
          executable = File.join(tasks_root, 'meta.sh')

          executor.expects(:run_task_with)
                  .with(target_mapping, mock_task(executable, 'environment'), {})
                  .returns(result_set)

          inventory.expects(:get_targets).with(hosts).returns(targets)

          is_expected.to(run
            .with_params('Test::Meta', hosts)
            .with_lambda { |_| task_params }
            .and_raise_error(Bolt::RunFailure))
        end

        it 'does not error with _catch_errors' do
          executable = File.join(tasks_root, 'meta.sh')

          executor.expects(:run_task_with)
                  .with(target_mapping, mock_task(executable, 'environment'), catch_errors: true)
                  .returns(result_set)

          inventory.expects(:get_targets).with(hosts).returns(targets)

          is_expected.to(run
            .with_params('Test::Meta', [hostname, hostname2], '_catch_errors' => true)
            .with_lambda { |_| task_params })
        end
      end
    end

    context 'when called on a module that contains manifests/init.pp' do
      it 'the call does not load init.pp' do
        executor.expects(:run_task).never
        inventory.expects(:get_targets).with([]).returns([])

        is_expected.to(run
          .with_params('test::echo', [])
          .with_lambda { |_| {} })
      end
    end

    context 'when called on a module that contains tasks/init.sh' do
      let(:target_mapping) { { target => task_params } }

      it 'finds task named after the module' do
        executable = File.join(tasks_root, 'init.sh')

        executor.expects(:run_task_with).with(target_mapping, mock_task(executable, nil), {}).returns(result_set)
        inventory.expects(:get_targets).with(hostname).returns([target])

        is_expected.to run
          .with_params('test', hostname)
          .with_lambda { |_| task_params }
          .and_return(result_set)
      end
    end

    it 'when called with non existing task - reports an unknown task error' do
      inventory.expects(:get_targets).with([]).returns([])

      is_expected.to run
        .with_params('test::nonesuch', [])
        .with_lambda { |_| {} }
        .and_raise_error(
          /Could not find a task named "test::nonesuch"/
        )
    end

    context 'with sensitive data parameters' do
      let(:sensitive) { Puppet::Pops::Types::PSensitiveType::Sensitive }
      let(:sensitive_string) { '$up3r$ecr3t!' }
      let(:sensitive_array)  { [1, 2, 3] }
      let(:sensitive_hash)   { { 'k' => 'v' } }
      let(:sensitive_json)   { "#{sensitive_string}\n#{sensitive_array}\n{\"k\":\"v\"}\n" }
      let(:result)           { Bolt::Result.new(target, value: { '_output' => sensitive_json }) }
      let(:result_set)       { Bolt::ResultSet.new([result]) }
      let(:task_params)      { {} }

      it 'with Sensitive metadata - input parameters are wrapped in Sensitive' do
        executable = File.join(tasks_root, 'sensitive_meta.sh')

        input_params = {
          'sensitive_string' => sensitive_string,
          'sensitive_array'  => sensitive_array,
          'sensitive_hash'   => sensitive_hash
        }

        expected_params = {
          'sensitive_string' => sensitive.new(sensitive_string),
          'sensitive_array'  => sensitive.new(sensitive_array),
          'sensitive_hash'   => sensitive.new(sensitive_hash)
        }

        target_mapping = { target => expected_params }

        sensitive.expects(:new).with(input_params['sensitive_string'])
                 .returns(expected_params['sensitive_string'])
        sensitive.expects(:new).with(input_params['sensitive_array'])
                 .returns(expected_params['sensitive_array'])
        sensitive.expects(:new).with(input_params['sensitive_hash'])
                 .returns(expected_params['sensitive_hash'])

        executor.expects(:run_task_with).with(target_mapping, mock_task(executable, nil), {}).returns(result_set)
        inventory.expects(:get_targets).with(hostname).returns(target)

        is_expected.to run
          .with_params('Test::Sensitive_Meta', hostname)
          .with_lambda { |_| input_params }
          .and_return(result_set)
      end
    end
  end

  context 'it validates the task parameters' do
    let(:task_name)   { 'Test::Params' }
    let(:hostname)    { 'a.b.com' }
    let(:target)      { inventory.get_target(hostname) }
    let(:task_params) { {} }

    it 'errors when the block does not return a Hash' do
      is_expected.to run
        .with_params(task_name, hostname)
        .with_lambda { |_| [] }
        .and_raise_error(Bolt::RunFailure)
    end

    it 'errors when unknown parameters are specified' do
      task_params.merge!(
        'foo' => nil,
        'bar' => nil
      )

      is_expected.to run
        .with_params(task_name, hostname)
        .with_lambda { |_| task_params }
        .and_raise_error(Bolt::RunFailure)
    end

    it 'errors when required parameters are not specified' do
      task_params['mandatory_string'] = 'str'

      is_expected.to run
        .with_params(task_name, hostname)
        .with_lambda { |_| task_params }
        .and_raise_error(Bolt::RunFailure)
    end

    it 'errors when the specified parameter values do not match the expected data types' do
      task_params.merge!(
        'mandatory_string' => 'str',
        'mandatory_integer' => 10,
        'mandatory_boolean' => 'str',
        'optional_string' => 10
      )

      is_expected.to run
        .with_params(task_name, hostname)
        .with_lambda { |_| task_params }
        .and_raise_error(Bolt::RunFailure)
    end

    it 'errors when the specified parameter values are outside of the expected ranges' do
      task_params.merge!(
        'mandatory_string' => '0123456789a',
        'mandatory_integer' => 10,
        'mandatory_boolean' => true,
        'optional_integer' => 10
      )

      is_expected.to run
        .with_params(task_name, hostname)
        .with_lambda { |_| task_params }
        .and_raise_error(Bolt::RunFailure)
    end

    it 'errors when a specified parameter value is not Data' do
      task_params.merge!(
        'mandatory_string' => 'str',
        'mandatory_integer' => 10,
        'mandatory_boolean' => true,
        'optional_hash' => { now: Time.now }
      )

      is_expected.to run
        .with_params(task_name, hostname)
        .with_lambda { |_| task_params }
        .and_raise_error(Bolt::RunFailure)
    end
  end
end
