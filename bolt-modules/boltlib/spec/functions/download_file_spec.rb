# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/result'
require 'bolt/result_set'
require 'bolt/target'
require 'bolt/project'

describe 'download_file' do
  include PuppetlabsSpec::Fixtures
  let(:executor)      { Bolt::Executor.new }
  let(:inventory)     { mock('inventory') }
  let(:project)       { Bolt::Project.default_project }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory, bolt_project: project) do
      inventory.stubs(:version).returns(2)
      inventory.stubs(:target_implementation_class).returns(Bolt::Target)
      example.run
    end
  end

  context 'it calls bolt executor download_file' do
    let(:hostname)    { 'test.example.com' }
    let(:target)      { Bolt::Target.new(hostname) }
    let(:message)     { 'downloaded' }
    let(:result)      { Bolt::Result.new(target, message: message) }
    let(:result_set)  { Bolt::ResultSet.new([result]) }
    let(:module_root) { File.expand_path(fixtures('modules', 'test')) }
    let(:source)      { '/path/to/source' }
    let(:destination) { 'downloads' }
    let(:project_destination) { project.downloads + destination }

    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
      Dir.stubs(:exist?).returns(false)
    end

    it 'with path of source and destination' do
      executor.expects(:download_file)
              .with([target], source, project_destination, {}, [])
              .returns(result_set)

      inventory.stubs(:get_targets)
               .with(hostname)
               .returns([target])

      is_expected.to run
        .with_params(source, destination, hostname)
        .and_return(result_set)
    end

    it 'raises an error when destination is an empty string' do
      destination = ' '

      executor.expects(:download_file).never

      inventory.stubs(:get_targets)
               .with(hostname)
               .returns([target])

      is_expected.to run
        .with_params(source, destination, hostname)
        .and_raise_error(Bolt::ValidationError)
    end

    it 'raises an error when destination is an aboslute path' do
      destination = '/downloads'

      executor.expects(:download_file).never

      inventory.stubs(:get_targets)
               .with(hostname)
               .returns([target])

      is_expected.to run
        .with_params(source, destination, hostname)
        .and_raise_error(Bolt::ValidationError)
    end

    it 'raises an error when destination includes path traversal' do
      destination = 'foo/../bar'

      executor.expects(:download_file).never

      inventory.stubs(:get_targets)
               .with(hostname)
               .returns([target])

      is_expected.to run
        .with_params(source, destination, hostname)
        .and_raise_error(Bolt::ValidationError)
    end

    it 'strips leading and trailing whitespace from the destination' do
      destination = " foo\n"
      project_destination = project.downloads + destination.strip

      executor.expects(:download_file)
              .with([target], source, project_destination, {}, [])
              .returns(result_set)

      inventory.stubs(:get_targets)
               .with(hostname)
               .returns([target])

      is_expected.to run
        .with_params(source, destination, hostname)
        .and_return(result_set)
    end

    it 'does not expand tilde in the destination' do
      destination = '~/foo'
      project_destination = project.downloads + destination

      executor.expects(:download_file)
              .with([target], source, project_destination, {}, [])
              .returns(result_set)

      inventory.stubs(:get_targets)
               .with(hostname)
               .returns([target])

      is_expected.to run
        .with_params(source, destination, hostname)
        .and_return(result_set)
    end

    it 'deletes contents of existing destination directory' do
      Dir.stubs(:exist?)
         .with(project_destination)
         .returns(true)

      FileUtils.stubs(:rm_r)

      executor.expects(:download_file)
              .with([target], source, project_destination, {}, [])
              .returns(result_set)

      inventory.stubs(:get_targets)
               .with(hostname)
               .returns([target])

      FileUtils.expects(:rm_r)
               .with([], secure: true)

      is_expected.to run
        .with_params(source, destination, hostname)
        .and_return(result_set)
    end

    it 'with target specified as a Target' do
      executor.expects(:download_file)
              .with([target], source, project_destination, {}, [])
              .returns(result_set)

      inventory.stubs(:get_targets)
               .with(target)
               .returns([target])

      is_expected.to run
        .with_params(source, destination, target)
        .and_return(result_set)
    end

    it 'runs as another user' do
      executor.expects(:download_file)
              .with([target], source, project_destination, { run_as: 'soandso' }, [])
              .returns(result_set)

      inventory.stubs(:get_targets)
               .with(target)
               .returns([target])

      is_expected.to run
        .with_params(source, destination, target, '_run_as' => 'soandso')
        .and_return(result_set)
    end

    it 'reports the call to analytics' do
      executor.expects(:download_file)
              .with([target], source, project_destination, {}, [])
              .returns(result_set)

      inventory.stubs(:get_targets)
               .with(hostname)
               .returns([target])

      executor.expects(:report_function_call)
              .with('download_file')

      is_expected.to run
        .with_params(source, destination, hostname)
        .and_return(result_set)
    end

    context 'with description' do
      let(:message) { 'test message' }

      it 'passes the description through if parameters are passed' do
        executor.expects(:download_file)
                .with([target], source, project_destination, { description: message }, [])
                .returns(result_set)

        inventory.stubs(:get_targets)
                 .with(target)
                 .returns([target])

        is_expected.to run
          .with_params(source, destination, target, message, {})
          .and_return(result_set)
      end

      it 'passes the description through if no parameters are passed' do
        executor.expects(:download_file)
                .with([target], source, project_destination, { description: message }, [])
                .returns(result_set)

        inventory.stubs(:get_targets)
                 .with(target)
                 .returns([target])

        is_expected.to run
          .with_params(source, destination, target, message)
          .and_return(result_set)
      end
    end

    context 'without description' do
      it 'ignores description if parameters are passed' do
        executor.expects(:download_file)
                .with([target], source, project_destination, {}, [])
                .returns(result_set)

        inventory.stubs(:get_targets)
                 .with(target)
                 .returns([target])

        is_expected.to run
          .with_params(source, destination, target, {})
          .and_return(result_set)
      end

      it 'ignores description if no parameters are passed' do
        executor.expects(:download_file)
                .with([target], source, project_destination, {}, [])
                .returns(result_set)

        inventory.stubs(:get_targets)
                 .with(target)
                 .returns([target])

        is_expected.to run
          .with_params(source, destination, target)
          .and_return(result_set)
      end
    end

    context 'with multiple sources' do
      let(:hostname2)  { 'test.testing.com' }
      let(:target2)    { Bolt::Target.new(hostname2) }
      let(:message2)   { 'received' }
      let(:result2)    { Bolt::Result.new(target2, message: message2) }
      let(:result_set) { Bolt::ResultSet.new([result, result2]) }

      it 'propagates multiple hosts and returns multiple results' do
        executor.expects(:download_file)
                .with([target, target2], source, project_destination, {}, [])
                .returns(result_set)

        inventory.stubs(:get_targets)
                 .with([hostname, hostname2])
                 .returns([target, target2])

        is_expected.to run
          .with_params(source, destination, [hostname, hostname2])
          .and_return(result_set)
      end

      context 'when download fails on one target' do
        let(:result2) { Bolt::Result.new(target2, error: { 'msg' => 'oops' }) }

        it 'errors by default' do
          executor.expects(:download_file)
                  .with([target, target2], source, project_destination, {}, [])
                  .returns(result_set)

          inventory.expects(:get_targets)
                   .with([hostname, hostname2])
                   .returns([target, target2])

          is_expected.to run
            .with_params(source, destination, [hostname, hostname2])
            .and_raise_error(Bolt::RunFailure)
        end

        it 'does not error with _catch_errors' do
          executor.expects(:download_file)
                  .with([target, target2], source, project_destination, { catch_errors: true }, [])
                  .returns(result_set)

          inventory.expects(:get_targets)
                   .with([hostname, hostname2])
                   .returns([target, target2])

          is_expected.to run
            .with_params(source, destination, [hostname, hostname2],
                         '_catch_errors' => true)
        end
      end
    end

    it 'without targets - does not invoke bolt' do
      executor.expects(:download_file).never
      inventory.expects(:get_targets).with([]).returns([])

      is_expected.to run
        .with_params(source, destination, [])
        .and_return(Bolt::ResultSet.new([]))
    end
  end

  context 'running in parallel' do
    let(:future) { mock('future') }
    let(:hostname) { 'test.example.com' }
    let(:target) { Bolt::Target.new(hostname) }
    let(:result) { Bolt::Result.new(target, value: { 'stdout' => hostname }) }
    let(:result_set) { Bolt::ResultSet.new([result]) }
    let(:source)      { '/path/to/source' }
    let(:destination) { 'downloads' }

    it 'executes in a thread if the executor is in parallel mode' do
      inventory.expects(:get_targets).with(hostname).returns([target])

      executor.expects(:in_parallel?).returns(true)
      executor.expects(:run_in_thread).returns(result_set)

      is_expected.to run
        .with_params(source, destination, hostname)
        .and_return(result_set)
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that download_file is not available' do
      is_expected.to run
        .with_params('/path/to/source', 'downloads', [])
        .and_raise_error(/Plan language function 'download_file' cannot be used/)
    end
  end
end
