# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config'
require 'bolt/result_set'

Bolt::ResultSet.include_iterable

RSpec.shared_context 'plan helper' do
  include RSpec::Puppet::FunctionExampleGroup # to be able to call find_function

  class MockInventory
    attr_reader :nodes, :targets

    def initialize
      @nodes = nil
      @targets = []
    end

    def populate(config, nodes)
      @nodes = nodes
      @targets = nodes.split(/[[:space:],]+/).reject(&:empty?).map { |node|
        target = Bolt::Target.new(node)
        protocol = target.protocol
        if protocol.nil? || config.transport_conf.key?(protocol)
          target.update_conf(config.transport_conf)
        end
        target
      }
    end

    def get_targets(targetspec)
      return @targets if targetspec == @nodes
      return targetspec if targetspec.is_a?(Array) && (targetspec - @targets).empty?
      raise "Unexpected invocation of Bolt::Inventory#get_targets with arguments: #{targetspec.inspect}"
    end

    def protocol_targets(*protocols, inverse: false)
      protocols = protocols.to_set
      @targets.select { |target| protocols.include?(target.protocol) ^ inverse }
    end
  end

  let(:run_plan_function) {
    # inject a global type alias for the 'Boltlib::TargetSpec'
    scope.compiler.context_overrides[:loaders].instance_exec do
      instantiate_definitions(
        Puppet::Pops::Parser::EvaluatingParser.singleton.parse_string(
          'type TargetSpec = Boltlib::TargetSpec'
        ),
        public_environment_loader
      )
    end

    find_function(:run_plan)
  }

  def run_plan(name, params)
    run_plan_function.execute(name, params)
  end

  def run_subject_plan(params)
    run_plan(self.class.top_level_description, params)
  end

  let(:executor) {
    mock('Bolt::Executor').tap do |executor|
      executor.stubs(:noop).returns(false)
    end
  }
  let(:inventory) { MockInventory.new }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.features.stubs(:bolt?).returns(true)

    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  let(:config) { Bolt::Config.new }

  def populate_mock_inventory(nodes)
    inventory.populate(config, nodes)
  end

  def generate_results(targets, error: nil)
    targets.map.with_index { |target, index|
      if block_given?
        Bolt::Result.new(target, value: yield(target, index))
      elsif error.nil?
        Bolt::Result.new(target, message: "Ran on #{target.name}")
      else
        Bolt::Result.new(target, error: error)
      end
    }
  end
end
