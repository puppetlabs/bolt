# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/result'
require 'bolt/result_set'
require 'bolt/target'

describe 'upload_file' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { mock('inventory') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      inventory.stubs(:version).returns(2)
      inventory.stubs(:target_implementation_class).returns(Bolt::Target)
      example.run
    end
  end

  context 'it calls bolt executor upload_file' do
    let(:hostname) { 'test.example.com' }
    let(:target) { Bolt::Target.new(hostname) }

    let(:message) { 'uploaded' }
    let(:result) { Bolt::Result.new(target, message: message) }
    let(:result_set) { Bolt::ResultSet.new([result]) }
    let(:module_root) { File.expand_path(fixtures('modules', 'test')) }
    let(:full_path) { File.join(module_root, 'files/uploads/index.html') }
    let(:full_dir_path) { File.dirname(full_path) }
    let(:destination) { '/var/www/html' }
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
    end

    it 'with fully resolved path of file and destination' do
      executor.expects(:upload_file)
              .with([target], full_path, destination, {}, [])
              .returns(result_set)
      inventory.stubs(:get_targets).with(hostname).returns([target])

      is_expected.to run
        .with_params('test/uploads/index.html', destination, hostname)
        .and_return(result_set)
    end

    it 'with fully resolved path of directory and destination' do
      executor.expects(:upload_file)
              .with([target], full_dir_path, destination, {}, [])
              .returns(result_set)
      inventory.stubs(:get_targets).with(hostname).returns([target])

      is_expected.to run
        .with_params('test/uploads', destination, hostname)
        .and_return(result_set)
    end

    context 'when locating files' do
      let(:module_root) { File.expand_path(fixtures('modules')) }

      before(:each) do
        inventory.stubs(:get_targets).with(hostname).returns([target])
      end

      context 'with nonspecific module syntax' do
        it 'does not load from scripts/ subdir' do
          is_expected.to run
            .with_params('with_scripts/hostname.sh', destination, hostname)
            .and_raise_error(/No such file or directory: .*with_scripts.*hostname\.sh/)
        end

        it 'loads from files/' do
          full_path = File.join(module_root, 'with_files/files/hostname.sh')

          executor.expects(:upload_file)
                  .with([target], full_path, destination, {}, [])
                  .returns(result_set)

          is_expected.to run
            .with_params('with_files/hostname.sh', destination, hostname)
            .and_return(result_set)
        end
      end

      context 'with scripts/ specified' do
        # hostname.sh is in with_both/files/scripts/ and with_both/scripts/
        it 'prefers loading from files/scripts/' do
          # Path that should be loaded from
          full_path = File.join(module_root, 'with_both/files/scripts/hostname.sh')

          executor.expects(:upload_file)
                  .with([target], full_path, destination, {}, [])
                  .returns(result_set)

          is_expected.to run
            .with_params('with_both/scripts/hostname.sh', destination, hostname)
            .and_return(result_set)
        end

        it 'falls back to scripts/ if not found in files/' do
          # Path that should be loaded from
          full_path = File.join(module_root, 'with_scripts/scripts/hostname.sh')

          executor.expects(:upload_file)
                  .with([target], full_path, destination, {}, [])
                  .returns(result_set)

          is_expected.to run
            .with_params('with_scripts/scripts/hostname.sh', destination, hostname)
            .and_return(result_set)
        end
      end

      context 'with files/ specified' do
        it 'prefers loading from files/files/' do
          # Path that should be loaded from
          full_path = File.join(module_root, 'with_files/files/files/hostname.sh')

          executor.expects(:upload_file)
                  .with([target], full_path, destination, {}, [])
                  .returns(result_set)

          is_expected.to run
            .with_params('with_files/files/hostname.sh', destination, hostname)
            .and_return(result_set)
        end

        it 'falls back to files/ if enabled' do
          # Path that should be loaded from
          full_path = File.join(module_root, 'with_files/files/toplevel.sh')

          executor.expects(:upload_file)
                  .with([target], full_path, destination, {}, [])
                  .returns(result_set)

          is_expected.to run
            .with_params('with_files/files/toplevel.sh', destination, hostname)
            .and_return(result_set)
        end
      end
    end

    it 'with target specified as a Target' do
      executor.expects(:upload_file)
              .with([target], full_dir_path, destination, {}, [])
              .returns(result_set)
      inventory.stubs(:get_targets).with(target).returns([target])

      is_expected.to run
        .with_params('test/uploads', destination, target)
        .and_return(result_set)
    end

    it 'runs as another user' do
      executor.expects(:upload_file)
              .with([target], full_dir_path, destination, { run_as: 'soandso' }, [])
              .returns(result_set)
      inventory.stubs(:get_targets).with(target).returns([target])

      is_expected.to run
        .with_params('test/uploads', destination, target, '_run_as' => 'soandso')
        .and_return(result_set)
    end

    it 'reports the call to analytics' do
      executor.expects(:upload_file)
              .with([target], full_path, destination, {}, [])
              .returns(result_set)
      inventory.stubs(:get_targets).with(hostname).returns([target])
      executor.expects(:report_function_call).with('upload_file')

      is_expected.to run
        .with_params('test/uploads/index.html', destination, hostname)
        .and_return(result_set)
    end

    context 'with description' do
      let(:message) { 'test message' }

      it 'passes the description through if parameters are passed' do
        executor.expects(:upload_file)
                .with([target], full_dir_path, destination, { description: message }, [])
                .returns(result_set)
        inventory.stubs(:get_targets).with(target).returns([target])

        is_expected.to run
          .with_params('test/uploads', destination, target, message, {})
          .and_return(result_set)
      end

      it 'passes the description through if no parameters are passed' do
        executor.expects(:upload_file)
                .with([target], full_dir_path, destination, { description: message }, [])
                .returns(result_set)
        inventory.stubs(:get_targets).with(target).returns([target])

        is_expected.to run
          .with_params('test/uploads', destination, target, message)
          .and_return(result_set)
      end
    end

    context 'without description' do
      it 'ignores description if parameters are passed' do
        executor.expects(:upload_file)
                .with([target], full_dir_path, destination, {}, [])
                .returns(result_set)
        inventory.stubs(:get_targets).with(target).returns([target])

        is_expected.to run
          .with_params('test/uploads', destination, target, {})
          .and_return(result_set)
      end

      it 'ignores description if no parameters are passed' do
        executor.expects(:upload_file)
                .with([target], full_dir_path, destination, {}, [])
                .returns(result_set)
        inventory.stubs(:get_targets).with(target).returns([target])

        is_expected.to run
          .with_params('test/uploads', destination, target)
          .and_return(result_set)
      end
    end

    context 'with multiple destinations' do
      let(:hostname2) { 'test.testing.com' }
      let(:target2) { Bolt::Target.new(hostname2) }
      let(:message2) { 'received' }
      let(:result2) { Bolt::Result.new(target2, message: message2) }
      let(:result_set) { Bolt::ResultSet.new([result, result2]) }

      it 'propagates multiple hosts and returns multiple results' do
        executor
          .expects(:upload_file).with([target, target2], full_path, destination, {}, [])
          .returns(result_set)
        inventory.stubs(:get_targets).with([hostname, hostname2]).returns([target, target2])

        is_expected.to run.with_params('test/uploads/index.html', destination, [hostname, hostname2])
                          .and_return(result_set)
      end

      context 'when upload fails on one target' do
        let(:result2) { Bolt::Result.new(target2, error: { 'msg' => 'oops' }) }

        it 'errors by default' do
          executor.expects(:upload_file)
                  .with([target, target2], full_path, destination, {}, [])
                  .returns(result_set)
          inventory.expects(:get_targets).with([hostname, hostname2]).returns([target, target2])

          is_expected.to run
            .with_params('test/uploads/index.html', destination, [hostname, hostname2])
            .and_raise_error(Bolt::RunFailure)
        end

        it 'does not error with _catch_errors' do
          executor.expects(:upload_file)
                  .with([target, target2], full_path, destination, { catch_errors: true }, [])
                  .returns(result_set)
          inventory.expects(:get_targets).with([hostname, hostname2]).returns([target, target2])

          is_expected.to run
            .with_params('test/uploads/index.html', destination, [hostname, hostname2], '_catch_errors' => true)
        end
      end
    end

    it 'without targets - does not invoke bolt' do
      executor.expects(:upload_file).never
      inventory.expects(:get_targets).with([]).returns([])

      is_expected.to run.with_params('test/uploads/index.html', destination, [])
                        .and_return(Bolt::ResultSet.new([]))
    end

    it 'errors when file is not found' do
      executor.expects(:upload_file).never

      is_expected.to run.with_params('test/uploads/nonesuch.html', destination, [])
                        .and_raise_error(/No such file or directory: .*nonesuch\.html/)
    end
  end

  context 'running in parallel' do
    let(:future) { mock('future') }
    let(:hostname) { 'test.example.com' }
    let(:target) { Bolt::Target.new(hostname) }
    let(:result) { Bolt::Result.new(target, value: { 'stdout' => hostname }) }
    let(:result_set) { Bolt::ResultSet.new([result]) }
    let(:destination) { '/var/www/html' }

    it 'executes in a thread if the executor is in parallel mode' do
      inventory.expects(:get_targets).with(hostname).returns([target])

      executor.expects(:in_parallel?).returns(true)
      executor.expects(:run_in_thread).returns(result_set)

      is_expected.to run
        .with_params('test/uploads/index.html', destination, hostname)
        .and_return(result_set)
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that upload_file is not available' do
      is_expected.to run.with_params('test/uploads/nonesuch.html', '/some/place', [])
                        .and_raise_error(/Plan language function 'upload_file' cannot be used/)
    end
  end
end
