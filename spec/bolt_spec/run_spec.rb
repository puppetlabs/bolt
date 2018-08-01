# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/run'

# In order to speed up tests there are only ssh versions of these specs
# While the target shouldn't matter this does mean this helper is not tested on
# windows controllers.
describe "BoltSpec::Run", ssh: true do
  include BoltSpec::Run
  include BoltSpec::Conn

  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:config_data) {
    { "modulepath" => modulepath,
      "ssh" =>  { "host-key-check" => false },
      "winrm" => { "ssl" => false } }
  }
  let(:inventory_data) { conn_inventory }

  describe 'run_task' do
    it 'should run a task on a node' do
      result = run_task('sample::echo', 'ssh', config: config_data, inventory: inventory_data)
      expect(result[0]['status']).to eq('success')
    end

    it 'should accept _catch_errors' do
      result = run_task('sample::echo', 'non_existent_ndoe', { '_catch_errors' => true },
                        config: config_data, inventory: inventory_data)

      expect(result[0]['status']).to eq('failure')
      expect(result[0]['result']['_error']['kind']).to eq('puppetlabs.tasks/connect-error')
    end
  end

  describe 'run_command' do
    it 'should run a command on a node', ssh: true do
      result = run_command('echo hello', 'ssh', config: config_data, inventory: inventory_data)
      expect(result[0]['status']).to eq('success')
    end

    it 'should accept _catch_errors' do
      result = run_command('echo hello', 'non_existent_ndoe', { '_catch_errors' => true },
                           config: config_data, inventory: inventory_data)

      expect(result[0]['status']).to eq('failure')
      expect(result[0]['result']['_error']['kind']).to eq('puppetlabs.tasks/connect-error')
    end
  end

  describe 'run_plan' do
    it 'should run a plan' do
      result = run_plan('sample::single_task', { 'nodes' => 'ssh' }, config: config_data, inventory: inventory_data)
      expect(result['status']).to eq('success')
      data = result['value'][0]
      expect(data['status']).to eq('success')
    end

    it 'should return a failure' do
      result = run_plan('error::run_fail', { 'target' => 'ssh' }, config: config_data, inventory: inventory_data)
      expect(result['status']).to eq('failure')
      expect(result['value']['kind']).to eq('bolt/run-failure')
    end
  end
end
