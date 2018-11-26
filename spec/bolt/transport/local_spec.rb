# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/local'
require 'bolt/target'
require 'bolt/inventory'

require_relative 'shared_examples'

describe Bolt::Transport::Local, bash: true do
  let(:runner) { Bolt::Transport::Local.new }
  let(:os_context) { posix_context }
  let(:transport_conf) { {} }
  let(:target) { Bolt::Target.new('local://localhost', transport_conf) }

  it 'is always connected' do
    expect(runner.connected?(target)).to eq(true)
  end

  include_examples 'transport api'

  context 'file errors' do
    before(:each) do
      allow(FileUtils).to receive(:cp_r).and_raise('no write')
      allow(Dir).to receive(:mktmpdir).with(no_args).and_raise('no tmpdir')
    end

    # TODO: move to transport API examples
    context 'when used as a proxy' do
      let(:inventory) { Bolt::Inventory.new({}) }
      let(:target)  do
        target = Bolt::Target.new('foo://user:pass@example.com/path/to?query=hey',
          'run-on' => 'localhost', 'device-type' => 'adevice')
        target.inventory = Bolt::Inventory.new({})
        target
      end

      it 'passes the correct _target' do
        with_task_containing('remote', "#!/bin/sh\ncat", 'stdin') do |task|
          result = local.run_task(target, task, {'param' => 'val'}).value
          expect(result).to include('param' => 'val')
          expect(result['_target']).to include("name"=>"foo://user:pass@example.com/path/to?query=hey")
          expect(result['_target']).to include('device-type' => 'adevice')
          expect(result['_target']).to include('host' => 'example.com')
        end
      end
    end

    include_examples 'transport failures'
  end
end
