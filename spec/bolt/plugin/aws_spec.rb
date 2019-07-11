# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/aws'

describe Bolt::Plugin::Aws::EC2 do
  let(:ip1) { '255.255.255.255' }
  let(:ip2) { '127.0.0.1' }
  let(:name1) { 'test-instance-1' }
  let(:name2) { 'test-instance-2' }
  let(:test_instances) {
    [
      { instance_id: name1,
        public_ip_address: ip1,
        public_dns_name: name1,
        state: { name: 'running' } },
      { instance_id: name2,
        public_ip_address: ip2,
        public_dns_name: name2,
        state: { name: 'running' } }
    ]
  }

  let(:test_client) {
    ::Aws::EC2::Client.new(
      stub_responses: { describe_instances: { reservations: [{ instances: test_instances }] } }
    )
  }

  let(:aws_dir) { File.expand_path(File.join(__dir__, '../../fixtures/configs')) }
  let(:plugin) { Bolt::Plugin::Aws::EC2.new(File.join(aws_dir, 'empty.yaml')) }

  let(:opts) do
    {
      'name' => 'public_dns_name',
      'uri' => 'public_ip_address',
      'filters' => [{ name: 'tag:Owner', values: ['foo'] }]
    }
  end

  before(:each) do
    plugin.client = test_client
  end

  it 'has a hook for inventory_targets' do
    expect(plugin.hooks).to eq(['inventory_targets'])
  end

  it 'matches all running instances' do
    targets = plugin.inventory_targets(opts)
    expect(targets).to contain_exactly({ 'name' => name1, 'uri' => ip1 },
                                       'name' => name2, 'uri' => ip2)
  end

  it 'sets only name if uri is not specified' do
    opts.delete('uri')
    targets = plugin.inventory_targets(opts)
    expect(targets).to contain_exactly({ 'name' => name1 },
                                       'name' => name2)
  end

  it 'returns nothing if neither name nor uri are specified' do
    targets = plugin.inventory_targets({})
    expect(targets).to be_empty
  end

  it 'builds a config map from the inventory' do
    config_template = { 'ssh' => { 'host' => 'public_ip_address' } }
    targets = plugin.inventory_targets(opts.merge('config' => config_template))

    config1 = { 'ssh' => { 'host' => ip1 } }
    config2 = { 'ssh' => { 'host' => ip2 } }
    expect(targets).to contain_exactly({ 'name' => name1, 'uri' => ip1, 'config' => config1 },
                                       'name' => name2, 'uri' => ip2, 'config' => config2)
  end

  it 'warns on missing instance properties' do
    opts['name'] = 'foo'
    expect(plugin).to receive(:warn_missing_attribute).twice.with(::Aws::EC2::Instance, /foo/)
    plugin.inventory_targets(opts)
  end

  it 'raises a validation error when credentials file path does not exist' do
    config_data = { 'aws' => { 'credentials' => '~/foo/credentials' } }
    boltdir = Bolt::Boltdir.new(File.join(Dir.tmpdir, rand(1000).to_s))
    config = Bolt::Config.new(boltdir, config_data)
    plugin = Bolt::Plugin::Aws::EC2.new(config)
    expect { plugin.config_client(opts) }.to raise_error(Bolt::ValidationError, %r{foo/credentials})
  end
end
