# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/logger'
require 'bolt_spec/errors'
require 'bolt_spec/files'
require 'bolt_spec/task'
require 'bolt_spec/transport'
require 'bolt/transport/lxd'
require 'bolt/config'
require 'bolt/inventory'
require 'bolt/util'

describe Bolt::Transport::LXD, lxd: true do
  include BoltSpec::Conn
  include BoltSpec::Errors
  include BoltSpec::Files
  include BoltSpec::Task

  let(:hostname)          { conn_info('ssh')[:host] }
  let(:port)              { conn_info('ssh')[:port] }

  let(:config)            { make_config }
  let(:project)           { Bolt::Project.new({}, '.') }
  let(:plugins)           { Bolt::Plugin.setup(config, nil) }
  let(:inventory)         { Bolt::Inventory.create_version({}, config.transport, config.transports, plugins) }
  let(:project)           { Bolt::Project.new({}, '.') }
  let(:lxd)               { Bolt::Transport::SSH.new }
  let(:target)            { make_target }

  let(:transport_config)  { {} }

  def make_config(conf: transport_config)
    conf = Bolt::Util.walk_keys(conf, &:to_s)
    Bolt::Config.new(project, 'lxd' => conf)
  end
  alias_method :mk_config, :make_config

  def make_target(host_: hostname, port_: port)
    inventory.get_target("#{host_}:#{port_}")
  end

  context 'with lxd' do
    it 'executes command on a target' do
      expect(lxd.run_command(target, "echo hello").value['stdout'].to eq("hello\n"))
    end
  end
end
