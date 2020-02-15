# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/run'

describe 'running a plan with write_file' do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Run

  let(:filename) { 'hello.txt' }
  let(:content) { 'Hello, world!' }
  let(:params) { %W[target=#{target} content=#{content} destination=#{filename}] }
  let(:modulepath) { File.expand_path(File.join(__dir__, '../../fixtures/modules')) }
  let(:inventory) { conn_inventory.merge(config) }
  let(:config) do
    {
      'config' => {
        'ssh' => { 'host-key-check' => false },
        'winrm' => { 'ssl' => false }
      }
    }
  end

  shared_examples 'when writing a file from a plan' do
    # Delete the uploaded file after each test
    after(:each) do
      result = run_command("#{remove_cmd} #{filename}", target, inventory: inventory)
      expect(result.first['status']).to eq('success')
    end

    it 'writes a file to the destination' do
      with_tempfile_containing('inventory', YAML.dump(inventory), '.yaml') do |inv|
        # Check that a file is correctly uploaded
        result = run_cli_json(%W[plan run write_file -i #{inv.path} -m #{modulepath}] + params)

        expect(result.size).to eq(1)
        data = result.first
        expect(data['status']).to eq('success')
        expect(data['value']['_output']).to match(/Uploaded .* to .*hello.txt/)

        # Check that the created file has the correct content
        result = run_command("#{print_cmd} #{filename}", target, inventory: inventory)

        expect(result.size).to eq(1)
        data = result.first
        expect(data['status']).to eq('success')
        expect(data['value']['stdout']).to match(/#{content}/)
      end
    end

    it 'reports multiple function calls to analytics' do
      with_tempfile_containing('inventory', YAML.dump(inventory), '.yaml') do |inv|
        expect_any_instance_of(Bolt::Executor).to receive(:report_function_call).with('write_file')
        expect_any_instance_of(Bolt::Executor).to receive(:report_function_call).with('file::write')
        expect_any_instance_of(Bolt::Executor).to receive(:report_function_call).with('upload_file')
        run_cli_json(%W[plan run write_file -i #{inv.path} -m #{modulepath}] + params)
      end
    end
  end

  describe 'over ssh', ssh: true do
    let(:target) { 'ssh' }
    let(:print_cmd) { 'cat' }
    let(:remove_cmd) { 'rm' }

    include_examples 'when writing a file from a plan'
  end

  describe 'over winrm', winrm: true do
    let(:target) { 'winrm' }
    let(:print_cmd) { 'type' }
    let(:remove_cmd) { 'del' }

    include_examples 'when writing a file from a plan'
  end
end
