# frozen_string_literal: true

require 'spec_helper'
require 'bolt/inventory'
require 'bolt_spec/config'

describe Bolt::Transport::Local do
  include BoltSpec::Config

  def get_target(inventory, name, alia = nil)
    targets = inventory.get_targets(alia || name)
    expect(targets.size).to eq(1)
    expect(targets[0].name).to eq(name)
    targets[0]
  end

  let(:pal)        { nil }
  let(:config)     { make_config }
  let(:plugins)    { Bolt::Plugin.new(config, pal) }
  let(:transports) { config.transports }
  let(:transport)  { config.transport }
  let(:inventory)  { Bolt::Inventory.create_version(data, transport, transports, plugins) }

  around :each do |example|
    target = get_target(inventory, uri)
    subject.with_connection(target) do |conn|
      @conn = conn
      example.run
    end
  end

  context 'with localhost' do
    let(:uri) { 'localhost' }

    context 'with no additional config' do
      let(:data) { { 'targets' => [uri] } }

      it 'adds magic config options' do
        expect(@conn.target.transport).to eq('local')
        expect(@conn.target.options['interpreters']).to include('.rb' => RbConfig.ruby)
        expect(@conn.target.features).to include('puppet-agent')
      end
    end

    context 'with group-level config' do
      let(:data) {
        { 'targets' => [uri],
          'config' => {
            'transport' => 'ssh',
            'local' => {
              'interpreters' => { '.rb' => '/foo/ruby' }
            }
          } }
      }

      it 'prefers default options' do
        expect(@conn.target.transport).to eq('local')
        expect(@conn.target.options['interpreters']).to include('.rb' => RbConfig.ruby)
        expect(@conn.target.features).to include('puppet-agent')
      end
    end

    context 'with target-level config' do
      let(:data) {
        { 'targets' => [{
          'name' => uri,
          'config' => {
            'transport' => 'ssh',
            'ssh' => {
              'interpreters' => { '.rb' => '/foo/ruby' }
            }
          }
        }] } # This has so many brackets it might be March Madness
      }

      it 'does not apply local defaults' do
        expect(@conn.target.transport).to eq('ssh')
        expect(@conn.target.options['interpreters']).to include('.rb' => '/foo/ruby')
        expect(@conn.target.features).not_to include('puppet-agent')
      end
    end
  end

  context 'with local target' do
    let(:uri) { 'local://127.0.0.1' }

    context 'with bundled-ruby' do
      let(:data) { { 'targets' => [uri] } }

      it 'adds local config options' do
        expect(@conn.target.transport).to eq('local')
        expect(@conn.target.options['interpreters']).to include('.rb' => RbConfig.ruby)
        expect(@conn.target.features).to include('puppet-agent')
      end
    end

    context 'without with_connection' do
      let(:data) { { 'targets' => [] } }
      it 'applies bundled-ruby config' do
        target = get_target(inventory, 'local://foo')
        expect(target.transport).to eq('local')
        expect(target.options['interpreters']).to include('.rb' => RbConfig.ruby)
        expect(target.features).to include('puppet-agent')
      end
    end

    context 'with group-level config' do
      let(:data) {
        { 'targets' => [uri],
          'config' => {
            'local' => {
              'interpreters' => { '.rb' => '/foo/ruby' }
            }
          },
          'features' => ['puppet-agent'] }
      }

      it 'prefers default options' do
        expect(@conn.target.options['interpreters']).to include('.rb' => RbConfig.ruby)
        expect(@conn.target.features).to eq(['puppet-agent'])
      end
    end

    context 'with target-level config' do
      let(:data) {
        { 'targets' => [{
          'name' => uri,
          'config' => {
            'transport' => 'local',
            'local' => {
              'interpreters' => { '.rb' => '/foo/ruby' }
            }
          }
        }] }
      }

      it 'prefers user-defined target-level config over defaults' do
        expect(@conn.target.options['interpreters']).to include('.rb' => '/foo/ruby')
        expect(@conn.target.features).to include('puppet-agent')
      end
    end
  end

  context 'with bundled-ruby false' do
    let(:uri) { 'local://127.0.0.1' }
    let(:data) {
      { 'targets' => [uri],
        'config' => { 'local' => { 'bundled-ruby' => false } } }
    }

    it 'does not use default config' do
      expect(@conn.target.options).not_to include('interpreters')
      expect(@conn.target.features).not_to include('puppet-agent')
    end

    it 'does not issue the warning' do
      expect(Bolt::Logger).not_to receive(:warn_once)
        .with(anything, /The local transport will default/)
      subject.with_connection(get_target(inventory, uri)) do |conn|
      end
    end

    it 'unbundles the env' do
      expect(Bundler).to receive(:with_unbundled_env)
      subject.with_connection(get_target(inventory, uri)) do |conn|
        conn.execute('ls')
      end
    end
  end
end
