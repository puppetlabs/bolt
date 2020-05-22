# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'bolt/catalog'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/puppetdb'
require 'bolt/target'

describe Bolt::Catalog do
  let(:uri) { 'catalog' }
  let(:target) { inventory.get_target(uri) }
  let(:inventory) { Bolt::Inventory.empty }
  let(:executor) { Bolt::Executor.new }
  let(:boltlib) { Bolt::PAL::BOLTLIB_PATH }
  let(:pdb_config) do
    Bolt::PuppetDB::Config.new('server_urls' => 'https://localhost:8081',
                               'cacert' => '/path/to/cacert',
                               'cert' => '/path/to/cert',
                               'key' => '/path/to/key',
                               'token' => 'token')
  end
  let(:catalog) { Bolt::Catalog.new('warning') }
  let(:notify) { "notify { \"trusted ${trusted}\": }" }
  let(:files) {
    <<~CODE
      file { '/root/test/':
        ensure => directory,
      } -> file { '/root/test/hello.txt':
        ensure  => file,
        content => "hi there I'm ${$facts['os']['family']}\n"
      }
    CODE
  }

  let(:plan) { File.join(__FILE__, '../../fixtures/apply/basic/plans/trusted.pp') }

  let(:request) do
    { 'code_ast' => {},
      'modulepath' => [],
      'pdb_config' => pdb_config.to_hash,
      'hiera_config' => nil,
      'plan_vars' => {},
      'target' => {
        'name' => uri,
        'facts' => {},
        'variables' => {},
        'trusted' => {
          'authenticated' => 'local',
          'certname' => uri,
          'extensions' => {},
          'hostname' => uri,
          'domain' => nil
        }
      },
      'config' => {
        'transport' => "ssh",
        'transports' => {
          'ssh' => { 'connect-timeout' => 10, tty: false, "host-key-check" => true },
          'winrm' => { 'connect-timeout' => 10, tty: false, ssl: true, "ssl-verify" => true },
          'pcp' => { 'connect-timeout' => 10,
                     'tty' => false,
                     'task-environment' => 'production' },
          'local' => { 'connect-timeout' => 10, tty: false }
        }
      } }
  end

  let(:plan_vars) do
    {
      "t1" => [{
        "__ptype" => "Target",
        "uri" => "targeta.example.com",
        "name" => "targetA",
        "safe_name" => "targetA",
        "target_alias" => [],
        "config" => {
          "ssh" => {
            "host-key-check" => false,
            "connect-timeout" => 100
          }
        },
        "facts" => {},
        "vars" => {},
        "features" => [],
        "plugin_hooks" => {},
        "resources" => {}
      }],
      "t2" => [{
        "__ptype" => "Target",
        "uri" => "targetb.example.com",
        "name" => "targetB",
        "safe_name" => "targetB",
        "target_alias" => [],
        "config" => {
          "ssh" => {
            "__ptype" => "LocalRef",
            "__pvalue" => "$['t1'][0]['config']['ssh']"
          }
        },
        "facts" => {},
        "vars" => {},
        "features" => [],
        "plugin_hooks" => {},
        "resources" => {}
      }]
    }
  end

  it 'instantiates' do
    expect(catalog).to be
  end

  describe 'generating an ast' do
    it 'generates an ast' do
      result = catalog.generate_ast(files)
      expect(result['__ptype']).to eq("Puppet::AST::Program")
      expect(result['locator']['string']).to eq(files)
    end
  end

  describe "compiling a catalog" do
    it 'compiles a catalog' do
      request["code_ast"] = catalog.generate_ast(notify)
      string = catalog.compile_catalog(request)
      # Turn output from string to hash
      result = JSON.parse string.gsub('=>', ':')
      expect(result['environment']).to eq('bolt_catalog')
      expect(result['resources'].map { |r| r['type'] }).to include('Notify')
      expect(result['resources'].count).to eq(4)
    end

    it 'resolves local references when deserializing Puppet types' do
      request.merge!(
        'code_ast'   => catalog.generate_ast(notify),
        'modulepath' => [boltlib],
        'plan_vars'  => plan_vars
      )
      expect { catalog.compile_catalog(request) }.not_to raise_error
    end
  end
end
