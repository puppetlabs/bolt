# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/target'
require 'bolt/result'
require 'bolt/result_set'

describe 'run_script' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { mock('inventory') }
  let(:tasks_enabled) { true }
  let(:module_root) { File.expand_path(fixtures('modules', 'test')) }
  let(:full_path) { File.join(module_root, 'files/uploads/hostname.sh') }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      inventory.stubs(:version).returns(2)
      inventory.stubs(:target_implementation_class).returns(Bolt::Target)
      example.run
    end
  end

  context 'it calls bolt executor run_script' do
    let(:hostname) { 'test.example.com' }
    let(:target) { Bolt::Target.new(hostname) }
    let(:result) { Bolt::Result.new(target, value: { 'stdout' => hostname }) }
    let(:result_set) { Bolt::ResultSet.new([result]) }
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
    end

    it 'with fully resolved path of file' do
      executor.expects(:run_script)
              .with([target], full_path, [], {}, [])
              .returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run
        .with_params('test/uploads/hostname.sh', hostname)
        .and_return(result_set)
    end

    it 'with host given as Target' do
      executor.expects(:run_script)
              .with([target], full_path, [], {}, [])
              .returns(result_set)
      inventory.expects(:get_targets).with(target).returns([target])

      is_expected.to run
        .with_params('test/uploads/hostname.sh', target)
        .and_return(result_set)
    end

    it 'with given arguments as a hash of {arguments => [value]}' do
      executor.expects(:run_script)
              .with([target], full_path, %w[hello world], {}, [])
              .returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run
        .with_params('test/uploads/hostname.sh',
                     hostname,
                     { 'arguments' => %w[hello world] })
        .and_return(result_set)
    end

    it 'with given arguments as a hash of {arguments => []}' do
      executor.expects(:run_script)
              .with([target], full_path, [], {}, [])
              .returns(result_set)
      inventory.expects(:get_targets).with(target).returns([target])

      is_expected.to run
        .with_params('test/uploads/hostname.sh', target, 'arguments' => [])
        .and_return(result_set)
    end

    it 'with pwsh_params' do
      executor.expects(:run_script)
              .with([target], full_path, [], { pwsh_params: { 'Name' => 'BoltyMcBoltface' } }, [])
              .returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run
        .with_params('test/uploads/hostname.sh',
                     hostname,
                     { 'pwsh_params' => { 'Name' => 'BoltyMcBoltface' } })
        .and_return(result_set)
    end

    it 'with _run_as' do
      executor.expects(:run_script)
              .with([target], full_path, [], { run_as: 'root' }, [])
              .returns(result_set)
      inventory.expects(:get_targets).with(target).returns([target])

      is_expected.to run
        .with_params('test/uploads/hostname.sh', target, '_run_as' => 'root')
        .and_return(result_set)
    end

    it 'reports the call to analytics' do
      executor.expects(:report_function_call).with('run_script')
      executor.expects(:run_script)
              .with([target], full_path, [], {}, [])
              .returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run
        .with_params('test/uploads/hostname.sh', hostname)
        .and_return(result_set)
    end

    context 'with description' do
      let(:message) { 'test message' }

      it 'passes the description through if parameters are passed' do
        executor.expects(:run_script)
                .with([target], full_path, [], { description: message }, [])
                .returns(result_set)
        inventory.expects(:get_targets).with(target).returns([target])

        is_expected.to run
          .with_params('test/uploads/hostname.sh', target, message, {})
      end

      it 'passes the description through if no parameters are passed' do
        executor.expects(:run_script)
                .with([target], full_path, [], { description: message }, [])
                .returns(result_set)
        inventory.expects(:get_targets).with(target).returns([target])

        is_expected.to run
          .with_params('test/uploads/hostname.sh', target, message)
      end
    end

    context 'without description' do
      it 'ignores description if parameters are passed' do
        executor.expects(:run_script)
                .with([target], full_path, [], {}, [])
                .returns(result_set)
        inventory.expects(:get_targets).with(target).returns([target])

        is_expected.to run
          .with_params('test/uploads/hostname.sh', target, {})
      end

      it 'ignores description if no parameters are passed' do
        executor.expects(:run_script)
                .with([target], full_path, [], {}, [])
                .returns(result_set)
        inventory.expects(:get_targets).with(target).returns([target])

        is_expected.to run
          .with_params('test/uploads/hostname.sh', target)
      end
    end

    context 'with multiple destinations' do
      let(:hostname2) { 'test.testing.com' }
      let(:target2) { Bolt::Target.new(hostname2) }
      let(:result2) { Bolt::Result.new(target2, value: { 'stdout' => hostname2 }) }
      let(:result_set) { Bolt::ResultSet.new([result, result2]) }

      it 'with propagated multiple hosts and returns multiple results' do
        executor.expects(:run_script)
                .with([target, target2], full_path, [], {}, [])
                .returns(result_set)
        inventory.expects(:get_targets).with([hostname, hostname2]).returns([target, target2])

        is_expected.to run
          .with_params('test/uploads/hostname.sh', [hostname, hostname2])
          .and_return(result_set)
      end

      context 'when a script fails on one target' do
        let(:result2) { Bolt::Result.new(target2, error: { 'message' => hostname2 }) }

        it 'errors by default' do
          executor.expects(:run_script)
                  .with([target, target2], full_path, [], {}, [])
                  .returns(result_set)
          inventory.expects(:get_targets).with([hostname, hostname2]).returns([target, target2])

          is_expected.to run
            .with_params('test/uploads/hostname.sh', [hostname, hostname2])
            .and_raise_error(Bolt::RunFailure)
        end

        it 'does not error with _catch_errors' do
          executor.expects(:run_script)
                  .with([target, target2], full_path, [], { catch_errors: true }, [])
                  .returns(result_set)
          inventory.expects(:get_targets).with([hostname, hostname2]).returns([target, target2])

          is_expected.to run
            .with_params('test/uploads/hostname.sh', [hostname, hostname2], '_catch_errors' => true)
        end
      end
    end

    it 'without targets - does not invoke bolt' do
      executor.expects(:run_script).never
      inventory.expects(:get_targets).with([]).returns([])

      is_expected.to run
        .with_params('test/uploads/hostname.sh', [])
        .and_return(Bolt::ResultSet.new([]))
    end

    it 'errors when script is not found' do
      executor.expects(:run_script).never

      is_expected.to run
        .with_params('test/uploads/nonesuch.sh', [])
        .and_raise_error(/No such file or directory: .*nonesuch\.sh/)
    end

    it 'errors when script appoints a directory' do
      executor.expects(:run_script).never

      is_expected.to run
        .with_params('test/uploads', [])
        .and_raise_error(%r{.*/uploads is not a file})
    end
  end

  context 'running in parallel' do
    let(:future) { mock('future') }
    let(:hostname) { 'test.example.com' }
    let(:target) { Bolt::Target.new(hostname) }
    let(:result) { Bolt::Result.new(target, value: { 'stdout' => hostname }) }
    let(:result_set) { Bolt::ResultSet.new([result]) }

    it 'executes in a thread if the executor is in parallel mode' do
      inventory.expects(:get_targets).with(hostname).returns([target])

      Concurrent::Future.expects(:execute).returns(future)
      future.expects(:incomplete?).returns(false)
      future.expects(:value).returns(result_set)
      executor.expects(:in_parallel).returns(true)

      is_expected.to run
        .with_params('test/uploads/hostname.sh', hostname)
        .and_return(result_set)
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that run_script is not available' do
      is_expected.to run
        .with_params('test/uploads/nonesuch.sh', [])
        .and_raise_error(/Plan language function 'run_script' cannot be used/)
    end
  end

  context 'with arguments and pwsh_params' do
    it 'fails' do
      is_expected.to run
        .with_params('test/uploads/script.sh', [], 'arguments' => [], 'pwsh_params' => {})
        .and_raise_error(/Cannot specify both 'arguments' and 'pwsh_params'/)
    end
  end

  it 'fails if arguments is not an array' do
    is_expected.to run
      .with_params('test/uploads/script.sh', [], 'arguments' => { 'foo' => 'bar' })
      .and_raise_error(/Option 'arguments' must be an array/)
  end

  it 'fails if pwsh_params is not a hash' do
    is_expected.to run
      .with_params('test/uploads/script.sh', [], 'pwsh_params' => %w[foo bar])
      .and_raise_error(/Option 'pwsh_params' must be a hash/)
  end

  context 'with _env_vars' do
    let(:targets) { ['localhost'] }

    it 'errors if _env_vars is not a hash' do
      is_expected.to run
        .with_params(full_path, targets, { '_env_vars' => 'value' })
        .and_raise_error(/Option 'env_vars' must be a hash/)
    end

    it 'errors if _env_vars keys are not strings' do
      is_expected.to run
        .with_params(full_path, targets, { '_env_vars' => { 1 => 'a' } })
        .and_raise_error(/Keys for option 'env_vars' must be strings: 1/)
    end

    it 'transforms values to json' do
      env_vars = { 'FRUIT' => { 'apple' => 'banana' } }
      options  = { env_vars: env_vars.transform_values(&:to_json) }

      executor.expects(:run_script)
              .with(targets, full_path, [], options, [])
              .returns(Bolt::ResultSet.new([]))
      inventory.expects(:get_targets)
               .with(targets)
               .returns(targets)

      is_expected.to run
        .with_params(full_path, targets, { '_env_vars' => env_vars })
    end
  end
end
