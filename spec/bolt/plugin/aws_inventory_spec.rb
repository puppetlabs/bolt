# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/aws_inventory'

describe Bolt::Plugin::AwsInventory do
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
  let(:plugin) { Bolt::Plugin::AwsInventory.new(config: File.join(aws_dir, 'empty.yaml')) }

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

  it 'matches all running instances' do
    targets = plugin.resolve_reference(opts)
    expect(targets).to contain_exactly({ 'name' => name1, 'uri' => ip1 },
                                       'name' => name2, 'uri' => ip2)
  end

  it 'sets only name if uri is not specified' do
    opts.delete('uri')
    targets = plugin.resolve_reference(opts)
    expect(targets).to contain_exactly({ 'name' => name1 },
                                       'name' => name2)
  end

  it 'returns nothing if neither name nor uri are specified' do
    targets = plugin.resolve_reference({})
    expect(targets).to be_empty
  end

  it 'builds a config map from the inventory' do
    config_template = { 'ssh' => { 'host' => 'public_ip_address' } }
    targets = plugin.resolve_reference(opts.merge('config' => config_template))

    config1 = { 'ssh' => { 'host' => ip1 } }
    config2 = { 'ssh' => { 'host' => ip2 } }
    expect(targets).to contain_exactly({ 'name' => name1, 'uri' => ip1, 'config' => config1 },
                                       'name' => name2, 'uri' => ip2, 'config' => config2)
  end

  it 'warns on missing instance properties' do
    opts['name'] = 'foo'
    expect(plugin).to receive(:warn_missing_attribute).twice.with(::Aws::EC2::Instance, /foo/)
    plugin.resolve_reference(opts)
  end

  it 'raises a validation error when credentials file path does not exist' do
    config_data = { 'credentials' => '~/foo/credentials' }
    plugin = Bolt::Plugin::AwsInventory.new(config: config_data)
    expect { plugin.config_client(opts) }.to raise_error(Bolt::ValidationError, %r{foo/credentials})
  end
end
