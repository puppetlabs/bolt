# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/result'
require 'bolt/result_set'
require 'bolt/target'
require 'puppet/pops/types/p_sensitive_type'
require 'rspec/expectations'

Sensitive = Puppet::Pops::Types::PSensitiveType::Sensitive

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

describe 'run_task' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { mock('Bolt::Inventory') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.features.stubs(:bolt?).returns(true)

    executor.stubs(:noop).returns(false)

    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  def mock_task(executable, input_method)
    TaskTypeMatcher.new(executable, input_method)
  end

  context 'it calls bolt executor run_task' do
    let(:hostname) { 'a.b.com' }
    let(:hostname2) { 'x.y.com' }
    let(:message) { 'the message' }
    let(:target) { Bolt::Target.new(hostname) }
    let(:target2) { Bolt::Target.new(hostname2) }
    let(:result) { Bolt::Result.new(target, value: { '_output' => message }) }
    let(:result2) { Bolt::Result.new(target2, value: { '_output' => message }) }
    let(:result_set) { Bolt::ResultSet.new([result]) }
    let(:tasks_root) { File.expand_path(fixtures('modules', 'test', 'tasks')) }
    let(:default_args) { { 'message' => message } }

    it 'when running a task without metadata the input method is "both"' do
      executable = File.join(tasks_root, 'echo.sh')

      executor.expects(:run_task).with([target], mock_task(executable, nil), default_args, {}).returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run.with_params('Test::Echo', hostname, default_args).and_return(result_set)
    end

    it 'when running a task with metadata - the input method is specified by the metadata' do
      executable = File.join(tasks_root, 'meta.sh')

      executor.expects(:run_task).with([target], mock_task(executable, 'environment'), default_args, {})
              .returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run.with_params('Test::Meta', hostname, default_args).and_return(result_set)
    end

    it 'when called with _run_as - _run_as is passed to the executor' do
      executable = File.join(tasks_root, 'meta.sh')

      executor.expects(:run_task)
              .with([target], mock_task(executable, 'environment'), default_args, '_run_as' => 'root')
              .returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      args = default_args.merge('_run_as' => 'root')
      is_expected.to run.with_params('Test::Meta', hostname, args).and_return(result_set)
    end

    it 'when called without without args hash (for a task where this is allowed)' do
      executable = File.join(tasks_root, 'yes.sh')

      executor.expects(:run_task).with([target], mock_task(executable, nil), {}, {}).returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run.with_params('test::yes', hostname).and_return(result_set)
    end

    it 'when called with no destinations - does not invoke bolt' do
      executor.expects(:run_task).never
      inventory.expects(:get_targets).with([]).returns([])

      is_expected.to run.with_params('Test::Yes', []).and_return(Bolt::ResultSet.new([]))
    end

    it 'reports the function call and task name to analytics' do
      executor.expects(:report_function_call).with('run_task')
      executor.expects(:report_bundled_content).with('Task', 'Test::Echo').once
      executable = File.join(tasks_root, 'echo.sh')

      executor.expects(:run_task).with([target], mock_task(executable, nil), default_args, {}).returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run.with_params('Test::Echo', hostname, default_args).and_return(result_set)
    end

    it 'skips reporting the function call to analytics if called internally from Bolt' do
      executor.expects(:report_function_call).with('run_task').never
      executable = File.join(tasks_root, 'echo.sh')

      executor.expects(:run_task)
              .with([target], mock_task(executable, nil), default_args, kind_of(Hash))
              .returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run.with_params('Test::Echo', hostname, default_args.merge('_bolt_api_call' => true))
                        .and_return(result_set)
    end

    context 'without tasks enabled' do
      let(:tasks_enabled) { false }

      it 'fails and reports that run_task is not available' do
        is_expected.to run
          .with_params('Test::Echo', hostname).and_raise_error(/Plan language function 'run_task' cannot be used/)
      end
    end

    context 'with description' do
      let(:message) { 'test message' }

      it 'passes the description through if parameters are passed' do
        executor.expects(:run_task).with([target], anything, {}, '_description' => message).returns(result_set)
        inventory.expects(:get_targets).with(hostname).returns([target])

        is_expected.to run.with_params('test::yes', hostname, message, {})
      end

      it 'passes the description through if no parameters are passed' do
        executor.expects(:run_task).with([target], anything, {}, '_description' => message).returns(result_set)
        inventory.expects(:get_targets).with(hostname).returns([target])

        is_expected.to run.with_params('test::yes', hostname, message)
      end
    end

    context 'without description' do
      it 'ignores description if parameters are passed' do
        executor.expects(:run_task).with([target], anything, {}, {}).returns(result_set)
        inventory.expects(:get_targets).with(hostname).returns([target])

        is_expected.to run.with_params('test::yes', hostname, {})
      end

      it 'ignores description if no parameters are passed' do
        executor.expects(:run_task).with([target], anything, {}, {}).returns(result_set)
        inventory.expects(:get_targets).with(hostname).returns([target])

        is_expected.to run.with_params('test::yes', hostname)
      end
    end

    context 'with multiple destinations' do
      let(:result_set) { Bolt::ResultSet.new([result, result2]) }

      it 'nodes can be specified as repeated nested arrays and strings and combine into one list of nodes' do
        executable = File.join(tasks_root, 'meta.sh')

        executor.expects(:run_task).with([target, target2], mock_task(executable, 'environment'), default_args, {})
                .returns(result_set)
        inventory.expects(:get_targets).with([hostname, [[hostname2]], []]).returns([target, target2])

        is_expected.to run.with_params('Test::Meta', [hostname, [[hostname2]], []], default_args)
                          .and_return(result_set)
      end

      it 'nodes can be specified as repeated nested arrays and Targets and combine into one list of nodes' do
        executable = File.join(tasks_root, 'meta.sh')

        executor.expects(:run_task).with([target, target2], mock_task(executable, 'environment'), default_args, {})
                .returns(result_set)
        inventory.expects(:get_targets).with([target, [[target2]], []]).returns([target, target2])

        is_expected.to run.with_params('Test::Meta', [target, [[target2]], []], default_args)
                          .and_return(result_set)
      end

      context 'when a command fails on one node' do
        let(:failresult) { Bolt::Result.new(target2, error: { 'msg' => 'oops' }) }
        let(:result_set) { Bolt::ResultSet.new([result, failresult]) }

        it 'errors by default' do
          executable = File.join(tasks_root, 'meta.sh')

          executor.expects(:run_task).with([target, target2], mock_task(executable, 'environment'), default_args, {})
                  .returns(result_set)
          inventory.expects(:get_targets).with([hostname, hostname2]).returns([target, target2])

          is_expected.to run.with_params('Test::Meta', [hostname, hostname2], default_args)
                            .and_raise_error(Bolt::RunFailure)
        end

        it 'does not error with _catch_errors' do
          executable = File.join(tasks_root, 'meta.sh')

          executor.expects(:run_task).with([target, target2],
                                           mock_task(executable, 'environment'),
                                           default_args,
                                           '_catch_errors' => true)
                  .returns(result_set)
          inventory.expects(:get_targets).with([hostname, hostname2]).returns([target, target2])

          args = default_args.merge('_catch_errors' => true)
          is_expected.to run.with_params('Test::Meta', [hostname, hostname2], args)
        end
      end
    end

    context 'when called on a module that contains manifests/init.pp' do
      it 'the call does not load init.pp' do
        executor.expects(:run_task).never
        inventory.expects(:get_targets).with([]).returns([])

        is_expected.to run.with_params('test::echo', [])
      end
    end

    context 'when called on a module that contains tasks/init.sh' do
      it 'finds task named after the module' do
        executable = File.join(tasks_root, 'init.sh')

        executor.expects(:run_task).with([target], mock_task(executable, nil), {}, {}).returns(result_set)
        inventory.expects(:get_targets).with(hostname).returns([target])

        is_expected.to run.with_params('test', hostname).and_return(result_set)
      end
    end

    it 'when called with non existing task - reports an unknown task error' do
      inventory.expects(:get_targets).with([]).returns([])

      is_expected.to run.with_params('test::nonesuch', []).and_raise_error(
        /Could not find a task named "test::nonesuch"/
      )
    end

    context 'with sensitive data parameters' do
      let(:sensitive_string) { '$up3r$ecr3t!' }
      let(:sensitive_array) { [1, 2, 3] }
      let(:sensitive_hash) { { 'k' => 'v' } }
      let(:sensitive_json) { "#{sensitive_string}\n#{sensitive_array}\n{\"k\":\"v\"}\n" }
      let(:result) { Bolt::Result.new(target, value: { '_output' => sensitive_json }) }
      let(:result_set) { Bolt::ResultSet.new([result]) }
      let(:task_params) { {} }

      it 'with Sensitive metadata - input parameters are wrapped in Sensitive' do
        executable = File.join(tasks_root, 'sensitive_meta.sh')
        input_params = {
          'sensitive_string' => sensitive_string,
          'sensitive_array' => sensitive_array,
          'sensitive_hash' => sensitive_hash
        }

        expected_params = {
          'sensitive_string' => Sensitive.new(sensitive_string),
          'sensitive_array' => Sensitive.new(sensitive_array),
          'sensitive_hash' => Sensitive.new(sensitive_hash)
        }

        Sensitive.expects(:new).with(input_params['sensitive_string'])
                 .returns(expected_params['sensitive_string'])
        Sensitive.expects(:new).with(input_params['sensitive_array'])
                 .returns(expected_params['sensitive_array'])
        Sensitive.expects(:new).with(input_params['sensitive_hash'])
                 .returns(expected_params['sensitive_hash'])

        executor.expects(:run_task).with([target], mock_task(executable, nil), expected_params, {})
                .returns(result_set)
        inventory.expects(:get_targets).with(hostname).returns([target])

        is_expected.to run.with_params('Test::Sensitive_Meta', hostname, input_params).and_return(result_set)
      end
    end
  end

  context 'it validates the task parameters' do
    let(:task_name) { 'Test::Params' }
    let(:hostname) { 'a.b.com' }
    let(:target) { Bolt::Target.new(hostname) }
    let(:task_params) { {} }

    before :each do
      inventory.expects(:get_targets).with(hostname).returns([target])
    end

    it 'errors when unknown parameters are specified' do
      task_params.merge!(
        'foo' => nil,
        'bar' => nil
      )

      is_expected.to run.with_params(task_name, hostname, task_params).and_raise_error(
        Puppet::ParseError,
        /Task\ test::params:\n
         \s*has\ no\ parameter\ named\ 'foo'\n
         \s*has\ no\ parameter\ named\ 'bar'/x
      )
    end

    it 'errors when required parameters are not specified' do
      task_params['mandatory_string'] = 'str'

      is_expected.to run.with_params(task_name, hostname, task_params).and_raise_error(
        Puppet::ParseError,
        /Task\ test::params:\n
         \s*expects\ a\ value\ for\ parameter\ 'mandatory_integer'\n
         \s*expects\ a\ value\ for\ parameter\ 'mandatory_boolean'/x
      )
    end

    it "errors when the specified parameter values don't match the expected data types" do
      task_params.merge!(
        'mandatory_string' => 'str',
        'mandatory_integer' => 10,
        'mandatory_boolean' => 'str',
        'optional_string' => 10
      )

      is_expected.to run.with_params(task_name, hostname, task_params).and_raise_error(
        Puppet::ParseError,
        /Task\ test::params:\n
         \s*parameter\ 'mandatory_boolean'\ expects\ a\ Boolean\ value,\ got\ String\n
         \s*parameter\ 'optional_string'\ expects\ a\ value\ of\ type\ Undef\ or\ String,
                                        \ got\ Integer/x
      )
    end

    it 'errors when the specified parameter values are outside of the expected ranges' do
      task_params.merge!(
        'mandatory_string' => '0123456789a',
        'mandatory_integer' => 10,
        'mandatory_boolean' => true,
        'optional_integer' => 10
      )

      is_expected.to run.with_params(task_name, hostname, task_params).and_raise_error(
        Puppet::ParseError,
        /Task\ test::params:\n
         \s*parameter\ 'mandatory_string'\ expects\ a\ String\[1,\ 10\]\ value,\ got\ String\n
         \s*parameter\ 'optional_integer'\ expects\ a\ value\ of\ type\ Undef\ or\ Integer\[-5,\ 5\],
                                         \ got\ Integer\[10,\ 10\]/x
      )
    end

    it "errors when a specified parameter value is not Data" do
      task_params.merge!(
        'mandatory_string' => 'str',
        'mandatory_integer' => 10,
        'mandatory_boolean' => true,
        'optional_hash' => { now: Time.now }
      )

      is_expected.to run.with_params(task_name, hostname, task_params).and_raise_error(
        Puppet::ParseError, /Task parameters are not of type Data. run_task()/
      )
    end
  end
end
