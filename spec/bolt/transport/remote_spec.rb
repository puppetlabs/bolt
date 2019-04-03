# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'

describe Bolt::Transport::Remote do
  it 'errors when a poxy is remote' do
    inventory = Bolt::Inventory.new('nodes' =>
                                     ["node1",
                                      { "name" => "node2",
                                        "config" => {
                                          "remote" => {
                                            "run-on" => "node1"
                                          }
                                        } }],
                                    'config' => { "transport" => "remote" })

    executor = Bolt::Executor.new
    remote_transport = executor.transports['remote'].value
    target = inventory.get_targets("node2").first

    expect { remote_transport.run_task(target, nil, {}) }.to raise_error(/node1 is not a valid run-on target/)
  end
end
