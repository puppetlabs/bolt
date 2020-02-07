# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/run'

describe 'running with an inventory file', reset_puppet_settings: true, ssh: true do
  include BoltSpec::Config
  include BoltSpec::Conn
  include BoltSpec::Run

  let(:conn) { conn_info('ssh') }
  let(:inventory) do
    { 'targets' => [
      { 'uri' => conn[:host],
        'config' => {
          'transport' => conn[:protocol],
          conn[:protocol] => {
            'user' => conn[:user],
            'port' => conn[:port],
            'password' => conn[:password]
          }
        } },
      { 'uri' => 'remote://simple.example.com',
        'config' => {
          'remote' => {
            'run-on' => conn[:host],
            'token' => 'token_val'
          }
        } },
      { 'uri' => 'https://www.example.com',
        'config' => {
          'transport' => 'remote',
          'remote' => { 'run-on': conn[:host] }
        } }
    ],
      'config' => {
        'ssh' => { 'host-key-check' => false },
        'winrm' => { 'ssl' => false, 'ssl-verify' => false }
      } }
  end

  let(:modulepath) { fixture_path('modules') }
  let(:config) { { 'modulepath' => modulepath } }

  it 'runs a remote task' do
    result = run_task('remote', 'remote://simple.example.com', {}, config: config, inventory: inventory).first
    expect(result).to include('status' => 'success')
    expect(result['result']['_target']).to include(
      'uri' => 'remote://simple.example.com',
      'host' => 'simple.example.com',
      'token' => 'token_val'
    )
  end

  it 'runs a remote task with the https protocol' do
    result = run_task('remote', 'https://www.example.com', {}, config: config, inventory: inventory).first
    expect(result).to include('status' => 'success')
    expect(result['result']['_target']).to include(
      'uri' => 'https://www.example.com',
      'host' => 'www.example.com',
      'protocol' => 'https'
    )
  end
end
