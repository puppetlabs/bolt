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

  def read_ast(str)
    Bolt::Catalog.new.with_puppet_settings do
      # rubocop:disable Security/Eval
      Puppet::Pops::Serialization::FromDataConverter.convert(eval(str))
      # rubocop:enable Security/Eval
    end
  end

  describe 'over ssh', ssh: true do
    let(:uri) { conn_uri('ssh') }
    let(:password) { conn_info('ssh')[:password] }
    let(:apply_task) { 'apply_catalog.sh' }

    it 'echos the catalog ast' do
      result = run_cli_json(%w[plan run basic --no-host-key-check] + config_flags)
      expect(result[0]['result']['_output']).to be
      expect(result[0]['result']['_output']).to match(%r{File.*/root/test/})
      expect(result[0]['result']['_output']).to match(/hi there I'm Debian/)

      ast = read_ast(result[0]['result']['_output'])
      expect(ast['catalog_uuid']).to be
      expect(ast['resources'].count).to eq(5)
    end
  end

  describe 'over winrm', winrm: true do
    let(:uri) { conn_uri('winrm') }
    let(:password) { conn_info('winrm')[:password] }
    let(:apply_task) { 'apply_catalog.ps1' }

    it 'echos the catalog ast' do
      result = run_cli_json(%w[plan run basic --no-ssl --no-ssl-verify] + config_flags)
      expect(result[0]['result']['_output']).to be
      expect(result[0]['result']['_output']).to match(%r{File.*/root/test/})
      expect(result[0]['result']['_output']).to match(/hi there I'm windows/)

      ast = read_ast(result[0]['result']['_output'])
      expect(ast['catalog_uuid']).to be
      expect(ast['resources'].count).to eq(5)
    end
  end
end
