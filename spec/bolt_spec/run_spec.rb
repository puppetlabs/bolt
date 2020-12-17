# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/run'

# In order to speed up tests there are only ssh versions of these specs
# While the target shouldn't matter this does mean this helper is not tested on
# windows controllers.
describe "BoltSpec::Run", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Run

  let(:modulepath) { fixtures_path('modules') }
  let(:bolt_config) {
    { "modulepath" => modulepath,
      "ssh" => { "host-key-check" => false },
      "winrm" => { "ssl" => false } }
  }
  let(:bolt_inventory) { conn_inventory }

  describe 'run_task' do
    it 'should run a task on a node' do
      result = run_task('sample::echo', 'ssh', {})
      expect(result[0]['status']).to eq('success')
    end

    it 'should accept _catch_errors' do
      result = run_task('sample::echo', 'non_existent_node', '_catch_errors' => true)

      expect(result[0]['status']).to eq('failure')
      expect(result[0]['value']['_error']['kind']).to eq('puppetlabs.tasks/connect-error')
    end
  end

  describe 'run_command' do
    it 'should run a command on a node', ssh: true do
      result = run_command('echo hello', 'ssh')
      expect(result[0]['status']).to eq('success')
    end

    it 'should accept _catch_errors' do
      result = run_command('echo hello', 'non_existent_node', options: { catch_errors: true })

      expect(result[0]['status']).to eq('failure')
      expect(result[0]['value']['_error']['kind']).to eq('puppetlabs.tasks/connect-error')
    end
  end

  describe 'run_script' do
    let(:script) { fixtures_path('scripts', 'success.sh') }

    it 'should run a command on a node with an argument', ssh: true do
      result = run_script(script, 'ssh', ['hi'])
      expect(result[0]['status']).to eq('success')
      expect(result[0]['value']['stdout']).to match(/arg: hi/)
    end

    it 'should accept _catch_errors' do
      result = run_script('missing.sh', 'non_existent_node', nil, options: { catch_errors: true })

      expect(result[0]['status']).to eq('failure')
      expect(result[0]['value']['_error']['kind']).to eq('puppetlabs.tasks/connect-error')
    end
  end

  describe 'upload_file' do
    let(:file) { fixtures_path('scripts', 'success.sh') }
    let(:dest) { "/tmp/#{SecureRandom.hex}" }

    it 'should upload a file to a node', ssh: true do
      result = upload_file(file, dest, 'ssh')
      expect(result[0]['status']).to eq('success')
    end

    it 'should accept _catch_errors' do
      result = run_script('missing.sh', 'non_existent_node', nil, options: { catch_errors: true })

      expect(result[0]['status']).to eq('failure')
      expect(result[0]['value']['_error']['kind']).to eq('puppetlabs.tasks/connect-error')
    end
  end

  describe 'run_plan' do
    it 'should run a plan' do
      result = run_plan('sample::single_task', 'nodes' => 'ssh')
      expect(result['status']).to eq('success')
      data = result['value'][0]
      expect(data['status']).to eq('success')
    end

    it 'should return a failure' do
      result = run_plan('error::run_fail', 'targets' => 'ssh')
      expect(result['status']).to eq('failure')
      expect(result['value']['kind']).to eq('bolt/run-failure')
    end
  end

  context 'with a target that has a puppet-agent installed' do
    def root_config
      { 'ssh' => {
        'run-as' => 'root',
        'sudo-password' => conn_info('ssh')[:password],
        'host-key-check' => false
      } }
    end

    before(:all) do
      result = run_task('puppet_agent::version', 'ssh', {}, inventory: conn_inventory, config: root_config)
      expect(result.first['status']).to eq('success')
      unless result.first['value']['version']
        result = run_task('puppet_agent::install', 'ssh', {}, inventory: conn_inventory, config: root_config)
      end
      expect(result.first['status']).to eq('success')
    end

    after(:all) do
      uninstall = '/opt/puppetlabs/bin/puppet resource package puppet-agent ensure=absent'
      run_command(uninstall, 'ssh', inventory: conn_inventory, config: root_config)
    end

    describe 'apply_manifest' do
      it 'should apply a manifest file' do
        bolt_inventory['features'] = ['puppet-agent']
        with_tempfile_containing('manifest', "notify { 'hello world': }", '.pp') do |manifest|
          results = apply_manifest(manifest.path, 'ssh')
          results.each do |result|
            expect(result['status']).to eq('success')
            expect(result.dig('value', 'report', 'resource_statuses')).to include('Notify[hello world]')
          end
        end
        bolt_inventory.delete('features')
      end

      it 'should apply a manifest code block' do
        bolt_inventory['features'] = ['puppet-agent']
        results = apply_manifest("notify { 'hello world': }", 'ssh', execute: true)
        results.each do |result|
          expect(result['status']).to eq('success')
          expect(result.dig('value', 'report', 'resource_statuses')).to include('Notify[hello world]')
        end
        bolt_inventory.delete('features')
      end

      it 'should raise an error when manifest file does not exist' do
        bolt_inventory['features'] = ['puppet-agent']
        expect do
          apply_manifest("missing.na", 'ssh')
        end.to raise_error(Bolt::FileError)
        bolt_inventory.delete('features')
      end

      it 'should return a failure' do
        bolt_inventory['features'] = ['puppet-agent']
        results = apply_manifest("fail()", 'ssh', execute: true)
        results.each do |result|
          expect(result['status']).to eq('failure')
          expect(result.dig('value', '_error', 'kind')).to eq('bolt/apply-error')
        end
        bolt_inventory.delete('features')
      end
    end
  end
end
