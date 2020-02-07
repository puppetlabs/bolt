# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/config'
require 'bolt/plugin'

describe Bolt::Transport::Remote do
  let(:config) { Bolt::Config.default }
  let(:plugins) { Bolt::Plugin.setup(config, nil, nil, Bolt::Analytics::NoopClient.new) }
  let(:data) {
    {
      'targets' => [
        'target1',
        { 'name' => 'target2',
          'config' => {
            'remote' => {
              'run-on' => 'target1'
            }
          } }
      ],
      'config' => {
        'transport' => 'remote'
      }
    }
  }

  it 'errors when a poxy is remote' do
    inventory = Bolt::Inventory.create_version(data, config, plugins)

    executor = Bolt::Executor.new
    remote_transport = executor.transports['remote'].value
    target = inventory.get_targets('target2').last

    expect { remote_transport.run_task(target, nil, {}) }.to raise_error(/target1 is not a valid run-on target/)
  end
end
