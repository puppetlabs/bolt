# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/integration'
require 'bolt_spec/conn'
require 'bolt/catalog'

describe "Passes parsed AST to the apply_catalog task" do
  include BoltSpec::Integration
  include BoltSpec::Conn

  let(:modulepath) { File.join(__dir__, '../fixtures/apply') }
  let(:config_flags) { %W[--format json --nodes #{uri} --password #{password} --modulepath #{modulepath}] + tflags }

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
    let(:tflags) { %w[--no-host-key-check] }

    it 'echos the catalog ast' do
      result = run_cli_json(%w[plan run basic] + config_flags)
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

    it 'uses trusted facts' do
      result = run_cli_json(%w[plan run basic::trusted] + config_flags)
      ast = result[0]['result']
      notify = ast['resources'].select { |r| r['type'] == 'Notify' }
      expect(notify.count).to eq(1)
      expect(notify[0]['title']).to eq(
        'trusted {authenticated => local, certname => localhost, extensions => {}, hostname => localhost, domain => }'
      )
    end

    it 'uses target vars' do
      result = run_cli_json(%w[plan run basic::target_vars] + config_flags)
      ast = result[0]['result']
      notify = ast['resources'].select { |r| r['type'] == 'Notify' }
      expect(notify.count).to eq(1)
      expect(notify[0]['title']).to eq('hello there')
    end

    it 'plan vars override target vars' do
      result = run_cli_json(%w[plan run basic::plan_vars] + config_flags)
      ast = result[0]['result']
      notify = ast['resources'].select { |r| r['type'] == 'Notify' }
      expect(notify.count).to eq(1)
      expect(notify[0]['title']).to eq('hello world')
    end
  end

  describe 'over winrm', winrm: true do
    let(:uri) { conn_uri('winrm') }
    let(:password) { conn_info('winrm')[:password] }
    let(:apply_task) { 'apply_catalog.ps1' }
    let(:tflags) { %w[--no-ssl --no-ssl-verify] }

    it 'echos the catalog ast' do
      result = run_cli_json(%w[plan run basic] + config_flags)
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

    it 'uses trusted facts' do
      result = run_cli_json(%w[plan run basic::trusted] + config_flags)
      ast = result[0]['result']
      notify = ast['resources'].select { |r| r['type'] == 'Notify' }
      expect(notify.count).to eq(1)
      expect(notify[0]['title']).to eq(
        'trusted {authenticated => local, certname => localhost, extensions => {}, hostname => localhost, domain => }'
      )
    end

    it 'uses target vars' do
      result = run_cli_json(%w[plan run basic::target_vars] + config_flags)
      ast = result[0]['result']
      notify = ast['resources'].select { |r| r['type'] == 'Notify' }
      expect(notify.count).to eq(1)
      expect(notify[0]['title']).to eq('hello there')
    end

    it 'plan vars override target vars' do
      result = run_cli_json(%w[plan run basic::plan_vars] + config_flags)
      ast = result[0]['result']
      notify = ast['resources'].select { |r| r['type'] == 'Notify' }
      expect(notify.count).to eq(1)
      expect(notify[0]['title']).to eq('hello world')
    end
  end
end
