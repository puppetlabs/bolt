require 'spec_helper'
require 'puppet/pops/types/execution_result'

describe 'run_script' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { mock('bolt_executor') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  context 'it calls bolt executor run_script' do
    let(:hostname) { 'test.example.com' }
    let(:hosts) { [hostname] }
    let(:host) { stub(uri: hostname) }
    let(:result) { { value: hostname } }
    let(:exec_result) { Puppet::Pops::Types::ExecutionResult.from_bolt(host => result) }
    let(:module_root) { File.expand_path(fixtures('modules', 'test')) }
    let(:full_path) { File.join(module_root, 'files/uploads/hostname.sh') }
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
    end

    it 'with fully resolved path of file' do
      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_script).with([host], full_path, []).returns(host => result)

      is_expected.to run.with_params('test/uploads/hostname.sh', hostname).and_return(exec_result)
    end

    it 'with host given as Target' do
      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_script).with([host], full_path, []).returns(host => result)

      target = Puppet::Pops::Types::TypeFactory.target.create(hostname)
      is_expected.to run.with_params('test/uploads/hostname.sh', target).and_return(exec_result)
    end

    it 'with given arguments as a hash of {arguments => [value]}' do
      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_script).with([host], full_path, %w[hello world]).returns(host => result)

      is_expected.to run.with_params('test/uploads/hostname.sh',
                                     hostname,
                                     'arguments' => %w[hello world]).and_return(exec_result)
    end

    it 'with given arguments as a hash of {arguments => []}' do
      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_script).with([host], full_path, []).returns(host => result)

      target = Puppet::Pops::Types::TypeFactory.target.create(hostname)
      is_expected.to run.with_params('test/uploads/hostname.sh', target, 'arguments' => []).and_return(exec_result)
    end

    context 'with multiple destinations' do
      let(:hostname2) { 'test.testing.com' }
      let(:hosts) { [hostname, hostname2] }
      let(:host2) { stub(uri: hostname2) }
      let(:result2) { { value: hostname2 } }
      let(:exec_result) { Puppet::Pops::Types::ExecutionResult.from_bolt(host => result, host2 => result2) }
      let(:nodes) { [mock(hostname), mock(hostname2)] }

      it 'with propagated multiple hosts and returns multiple results' do
        executor.expects(:from_uris).with(hosts).returns(nodes)
        executor.expects(:run_script).with(nodes, full_path, []).returns(host => result, host2 => result2)

        is_expected.to run.with_params('test/uploads/hostname.sh', hostname, hostname2).and_return(exec_result)
      end
    end

    it 'without nodes - does not invoke bolt' do
      executor.expects(:from_uris).never
      executor.expects(:run_script).never

      is_expected.to run
        .with_params('test/uploads/hostname.sh').and_return(Puppet::Pops::Types::ExecutionResult::EMPTY_RESULT)
    end

    it 'errors when script is not found' do
      executor.expects(:from_uris).never
      executor.expects(:run_script).never

      is_expected.to run
        .with_params('test/uploads/nonesuch.sh').and_raise_error(/No such file or directory: .*nonesuch\.sh/)
    end

    it 'errors when script appoints a directory' do
      executor.expects(:from_uris).never
      executor.expects(:run_script).never

      is_expected.to run.with_params('test/uploads').and_raise_error(%r{.*\/uploads is not a file})
    end
  end

  context 'without bolt feature present' do
    it 'fails and reports that bolt library is required' do
      Puppet.features.stubs(:bolt?).returns(false)
      is_expected.to run
        .with_params('test/uploads/nonesuch.sh').and_raise_error(/The 'bolt' library is required to run a script/)
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that run_script is not available' do
      is_expected.to run
        .with_params('test/uploads/nonesuch.sh').and_raise_error(/The task operation 'run_script' is not available/)
    end
  end
end
