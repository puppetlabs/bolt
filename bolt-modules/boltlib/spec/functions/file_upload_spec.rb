require 'spec_helper'
require 'bolt/result'
require 'bolt/result_set'
require 'bolt/target'

describe 'file_upload' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { mock('bolt_executor') }
  let(:inventory) { mock('inventory') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  context 'it calls bolt executor file_upload' do
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
      executor.expects(:file_upload).with([target], full_path, destination, {}).returns(result_set)
      inventory.stubs(:get_targets).with(hostname).returns([target])

      is_expected.to run.with_params('test/uploads/index.html', destination, hostname).and_return(result_set)
    end

    it 'with fully resolved path of directory and destination' do
      executor.expects(:file_upload).with([target], full_dir_path, destination, {}).returns(result_set)
      inventory.stubs(:get_targets).with(hostname).returns([target])

      is_expected.to run.with_params('test/uploads', destination, hostname).and_return(result_set)
    end

    it 'with target specified as a Target' do
      executor.expects(:file_upload).with([target], full_dir_path, destination, {}).returns(result_set)
      inventory.stubs(:get_targets).with(target).returns([target])

      is_expected.to run.with_params('test/uploads', destination, target).and_return(result_set)
    end

    it 'runs as another user' do
      executor.expects(:file_upload)
              .with([target], full_dir_path, destination, '_run_as' => 'soandso')
              .returns(result_set)
      inventory.stubs(:get_targets).with(target).returns([target])

      is_expected.to run.with_params('test/uploads', destination, target, '_run_as' => 'soandso').and_return(result_set)
    end

    context 'with multiple destinations' do
      let(:hostname2) { 'test.testing.com' }
      let(:target2) { Bolt::Target.new(hostname2) }
      let(:message2) { 'received' }
      let(:result2) { Bolt::Result.new(target2, message: message2) }
      let(:result_set) { Bolt::ResultSet.new([result, result2]) }

      it 'propagates multiple hosts and returns multiple results' do
        executor
          .expects(:file_upload).with([target, target2], full_path, destination, {})
          .returns(result_set)
        inventory.stubs(:get_targets).with([hostname, hostname2]).returns([target, target2])

        is_expected.to run.with_params('test/uploads/index.html', destination, [hostname, hostname2])
                          .and_return(result_set)
      end

      context 'when upload fails on one node' do
        let(:result2) { Bolt::Result.new(target2, error: { 'msg' => 'oops' }) }

        it 'errors by default' do
          executor.expects(:file_upload).with([target, target2], full_path, destination, {})
                  .returns(result_set)
          inventory.expects(:get_targets).with([hostname, hostname2]).returns([target, target2])

          is_expected.to run.with_params('test/uploads/index.html', destination, [hostname, hostname2])
                            .and_raise_error(Bolt::RunFailure)
        end

        it 'does not error with _catch_errors' do
          executor.expects(:file_upload).with([target, target2], full_path, destination, {})
                  .returns(result_set)
          inventory.expects(:get_targets).with([hostname, hostname2]).returns([target, target2])

          is_expected.to run.with_params('test/uploads/index.html', destination, [hostname, hostname2],
                                         '_catch_errors' => true)
        end
      end
    end

    it 'without nodes - does not invoke bolt' do
      executor.expects(:file_upload).never
      inventory.expects(:get_targets).with([]).returns([])

      is_expected.to run.with_params('test/uploads/index.html', destination, [])
                        .and_return(Bolt::ResultSet.new([]))
    end

    it 'errors when file is not found' do
      executor.expects(:file_upload).never

      is_expected.to run.with_params('test/uploads/nonesuch.html', destination, [])
                        .and_raise_error(/No such file or directory: .*nonesuch\.html/)
    end
  end

  context 'without bolt feature present' do
    it 'fails and reports that bolt library is required' do
      Puppet.features.stubs(:bolt?).returns(false)
      is_expected.to run.with_params('test/uploads/nonesuch.html', '/some/place', [])
                        .and_raise_error(/The 'bolt' library is required to do file uploads/)
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that file_upload is not available' do
      is_expected.to run.with_params('test/uploads/nonesuch.html', '/some/place', [])
                        .and_raise_error(/The task operation 'file_upload' is not available/)
    end
  end
end
