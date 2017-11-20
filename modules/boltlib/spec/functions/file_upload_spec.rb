require 'spec_helper'
require 'puppet/pops/types/execution_result'

describe 'file_upload' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { mock('bolt_executor') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  context 'it calls bolt executor file_upload' do
    let(:hostname) { 'test.example.com' }
    let(:hosts) { [hostname] }
    let(:host) { stub(uri: hostname) }
    let(:message) { 'uploaded' }
    let(:result) { { value: message } }
    let(:exec_result) { Puppet::Pops::Types::ExecutionResult.from_bolt(host => result) }
    let(:module_root) { File.expand_path(fixtures('modules', 'test')) }
    let(:full_path) { File.join(module_root, 'files/uploads/index.html') }
    let(:full_dir_path) { File.dirname(full_path) }
    let(:destination) { '/var/www/html' }
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
    end

    it 'with fully resolved path of file and destination' do
      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:file_upload).with([host], full_path, destination).returns(host => result)

      is_expected.to run.with_params('test/uploads/index.html', destination, hostname).and_return(exec_result)
    end

    it 'with fully resolved path of directory and destination' do
      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:file_upload).with([host], full_dir_path, destination).returns(host => result)

      is_expected.to run.with_params('test/uploads', destination, hostname).and_return(exec_result)
    end

    it 'with target specified as a Target' do
      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:file_upload).with([host], full_dir_path, destination).returns(host => result)

      target = Puppet::Pops::Types::TypeFactory.target.create(hostname)
      is_expected.to run.with_params('test/uploads', destination, target).and_return(exec_result)
    end

    context 'with multiple destinations' do
      let(:hostname2) { 'test.testing.com' }
      let(:hosts) { [hostname, hostname2] }
      let(:host2) { stub(uri: hostname2) }
      let(:message2) { 'received' }
      let(:result2) { { value: message2 } }
      let(:exec_result) { Puppet::Pops::Types::ExecutionResult.from_bolt(host => result, host2 => result2) }

      it 'propagates multiple hosts and returns multiple results' do
        executor.expects(:from_uris).with(hosts).returns([host, host2])
        executor.expects(:file_upload).with([host, host2], full_path, destination).returns(host => result,
                                                                                           host2 => result2)

        is_expected.to run.with_params('test/uploads/index.html', destination, hostname, hostname2)
                          .and_return(exec_result)
      end
    end

    it 'without nodes - does not invoke bolt' do
      executor.expects(:from_uris).never
      executor.expects(:file_upload).never

      is_expected.to run.with_params('test/uploads/index.html', destination)
                        .and_return(Puppet::Pops::Types::ExecutionResult::EMPTY_RESULT)
    end

    it 'errors when file is not found' do
      executor.expects(:from_uris).never
      executor.expects(:file_upload).never

      is_expected.to run.with_params('test/uploads/nonesuch.html', destination)
                        .and_raise_error(/No such file or directory: .*nonesuch\.html/)
    end
  end

  context 'without bolt feature present' do
    it 'fails and reports that bolt library is required' do
      Puppet.features.stubs(:bolt?).returns(false)
      is_expected.to run.with_params('test/uploads/nonesuch.html', '/some/place')
                        .and_raise_error(/The 'bolt' library is required to do file uploads/)
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that file_upload is not available' do
      is_expected.to run.with_params('test/uploads/nonesuch.html', '/some/place')
                        .and_raise_error(/The task operation 'file_upload' is not available/)
    end
  end
end
