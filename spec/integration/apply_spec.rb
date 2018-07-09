# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/integration'
require 'bolt_spec/conn'
require 'bolt/catalog'

describe "Passes parsed AST to the apply_catalog task" do
  include BoltSpec::Integration
  include BoltSpec::Conn

  let(:modulepath) { File.join(__dir__, '../fixtures/apply') }
  let(:config_flags) { %W[--format json --nodes #{uri} --password #{password} --modulepath #{modulepath}] }

  before(:each) do
    allow_any_instance_of(Bolt::Applicator).to receive(:catalog_apply_task) {
      path = File.join(__dir__, "../fixtures/apply/#{apply_task}")
      impl = { 'name' => apply_task, 'path' => path, 'requirements' => [], 'supports_noop' => true }
      Bolt::Task.new('apply_catalog', [impl], 'environment')
    }
  end

  describe 'over ssh', ssh: true do
    let(:uri) { conn_uri('ssh') }
    let(:password) { conn_info('ssh')[:password] }
    let(:apply_task) { 'apply_catalog.sh' }

    it 'echos the catalog ast' do
      result = run_cli_json(%w[plan run basic --no-host-key-check] + config_flags)
      ast = result[0]['result']
      expect(ast).to be
      expect(ast['catalog_uuid']).to be
      expect(ast['resources'].count).to eq(5)

      resources = ast['resources'].group_by { |r| r['type'] }
      expect(resources['File'].count).to eq(2)
      files = resources['File'].select { |f| f['title'] == '/root/test/hello.txt' }
      expect(files.count).to eq(1)
      expect(files[0]['parameters']['content']).to match(/hi there I'm Debian/)
    end
  end

  describe 'over winrm', winrm: true do
    let(:uri) { conn_uri('winrm') }
    let(:password) { conn_info('winrm')[:password] }
    let(:apply_task) { 'apply_catalog.ps1' }

    it 'echos the catalog ast' do
      result = run_cli_json(%w[plan run basic --no-ssl --no-ssl-verify] + config_flags)
      ast = result[0]['result']
      expect(ast).to be
      expect(ast['catalog_uuid']).to be
      expect(ast['resources'].count).to eq(5)

      resources = ast['resources'].group_by { |r| r['type'] }
      expect(resources['File'].count).to eq(2)
      files = resources['File'].select { |f| f['title'] == '/root/test/hello.txt' }
      expect(files.count).to eq(1)
      expect(files[0]['parameters']['content']).to match(/hi there I'm windows/)
    end
  end
end
