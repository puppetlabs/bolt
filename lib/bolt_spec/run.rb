# frozen_string_literal: true

# shorthand for requiring the parts of bolt we need
require 'bolt/cli'
require 'bolt/util'

# This is intended to provide a relatively stable method of executing bolt in process from tests.
# Currently it provides run_task, run_plan and run_command helpers.
module BoltSpec
  module Run
    def run_task(task_name, targets, params = nil, config: nil, inventory: nil)
      result = BoltRunner.with_runner(config, inventory) do |runner|
        runner.run_task(task_name, targets, params || {})
      end
      result = result.to_a
      Bolt::Util.walk_keys(result, &:to_s)
    end

    def run_plan(plan_name, params = nil, config: nil, inventory: nil)
      # Users copying code from run_task may forget that targets is not a parameter for run plan
      raise ArgumentError, "params must be a hash" unless params.is_a?(Hash)

      result = BoltRunner.with_runner(config, inventory) do |runner|
        runner.run_plan(plan_name, params || {})
      end

      { "status" => result.status,
        "value" => JSON.parse(result.value.to_json) }
    end

    def run_command(command, targets, params = nil, config: nil, inventory: nil)
      result = BoltRunner.with_runner(config, inventory) do |runner|
        runner.run_command(command, targets, params)
      end
      result = result.to_a
      Bolt::Util.walk_keys(result, &:to_s)
    end

    class BoltRunner
      # Creates a temporary boltdir so no settings are picked up
      # WARNING: puppetdb config and orch config which do not use the boltdir may
      # still be loaded
      def self.with_runner(config_data, inventory_data)
        Dir.mktmpdir do |boltdir_path|
          config = Bolt::Config.new(Bolt::Boltdir.new(boltdir_path), config_data || {})
          inventory = Bolt::Inventory.new(inventory_data || {}, config)
          yield new(config, inventory)
        end
      end

      attr_reader :config, :inventory

      def initialize(config, inventory)
        @config = config
        @inventory = inventory
        @analytics = Bolt::Analytics::NoopClient.new
      end

      def puppetdb_client
        @puppetdb_client ||= begin
                               puppetdb_config = Bolt::PuppetDB::Config.load_config(nil, config.puppetdb)
                               Bolt::PuppetDB::Client.new(puppetdb_config)
                             end
      end

      def pal
        @pal ||= Bolt::PAL.new(config.modulepath, config.hiera_config, config.compile_concurrency)
      end

      def resolve_targets(target_spec)
        @inventory.get_targets(target_spec).map(&:name)
      end

      # Adapted from CLI
      def run_task(task_name, targets, params, noop: false)
        executor = Bolt::Executor.new(config.concurrency, @analytics, noop)
        pal.run_task(task_name, targets, params, executor, inventory, nil) { |_ev| nil }
      end

      # Adapted from CLI does not handle nodes or plan_job reporting
      def run_plan(plan_name, params, noop: false)
        executor = Bolt::Executor.new(config.concurrency, @analytics, noop)
        pal.run_plan(plan_name, params, executor, inventory, puppetdb_client)
      end

      def run_command(command, targets, params = nil)
        executor = Bolt::Executor.new(config.concurrency, @analytics)
        targets = inventory.get_targets(targets)
        executor.run_command(targets, command, params || {})
      end
    end
  end
end
