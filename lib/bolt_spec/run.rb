# frozen_string_literal: true

require 'bolt/analytics'
require 'bolt/config'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/pal'
require 'bolt/plugin'
require 'bolt/puppetdb'
require 'bolt/util'
require 'bolt/logger'

# This is intended to provide a relatively stable method of executing bolt in process from tests.
module BoltSpec
  module Run
    def run_task(task_name, targets, params, config: nil, inventory: nil)
      if config.nil? && defined?(bolt_config)
        config = bolt_config
      end

      if inventory.nil? && defined?(bolt_inventory)
        inventory = bolt_inventory
      end

      result = BoltRunner.with_runner(config, inventory) do |runner|
        runner.run_task(task_name, targets, params)
      end
      result = result.to_a
      Bolt::Util.walk_keys(result, &:to_s)
    end

    def run_plan(plan_name, params, config: nil, inventory: nil)
      if config.nil? && defined?(bolt_config)
        config = bolt_config
      end

      if inventory.nil? && defined?(bolt_inventory)
        inventory = bolt_inventory
      end

      # Users copying code from run_task may forget that targets is not a parameter for run plan
      raise ArgumentError, "params must be a hash" unless params.is_a?(Hash)

      result = BoltRunner.with_runner(config, inventory) do |runner|
        runner.run_plan(plan_name, params)
      end

      { "status" => result.status,
        "value" => JSON.parse(result.value.to_json) }
    end

    def run_command(command, targets, options: {}, config: nil, inventory: nil)
      if config.nil? && defined?(bolt_config)
        config = bolt_config
      end

      if inventory.nil? && defined?(bolt_inventory)
        inventory = bolt_inventory
      end

      result = BoltRunner.with_runner(config, inventory) do |runner|
        runner.run_command(command, targets, options)
      end
      result = result.to_a
      Bolt::Util.walk_keys(result, &:to_s)
    end

    def run_script(script, targets, arguments, options: {}, config: nil, inventory: nil)
      if config.nil? && defined?(bolt_config)
        config = bolt_config
      end

      if inventory.nil? && defined?(bolt_inventory)
        inventory = bolt_inventory
      end

      result = BoltRunner.with_runner(config, inventory) do |runner|
        runner.run_script(script, targets, arguments, options)
      end
      result = result.to_a
      Bolt::Util.walk_keys(result, &:to_s)
    end

    def download_file(source, dest, targets, options: {}, config: nil, inventory: nil)
      if config.nil? && defined?(bolt_config)
        config = bolt_config
      end

      if inventory.nil? && defined?(bolt_inventory)
        inventory = bolt_inventory
      end

      result = BoltRunner.with_runner(config, inventory) do |runner|
        runner.download_file(source, dest, targets, options)
      end
      result = result.to_a
      Bolt::Util.walk_keys(result, &:to_s)
    end

    def upload_file(source, dest, targets, options: {}, config: nil, inventory: nil)
      if config.nil? && defined?(bolt_config)
        config = bolt_config
      end

      if inventory.nil? && defined?(bolt_inventory)
        inventory = bolt_inventory
      end

      result = BoltRunner.with_runner(config, inventory) do |runner|
        runner.upload_file(source, dest, targets, options)
      end
      result = result.to_a
      Bolt::Util.walk_keys(result, &:to_s)
    end

    def apply_manifest(manifest, targets, execute: false, noop: false, config: nil, inventory: nil)
      if config.nil? && defined?(bolt_config)
        config = bolt_config
      end

      if inventory.nil? && defined?(bolt_inventory)
        inventory = bolt_inventory
      end

      # The execute parameter is equivalent to the --execute option
      if execute
        code = manifest
      else
        begin
          unless File.stat(manifest).readable?
            raise Bolt::FileError.new("The manifest '#{manifest}' is unreadable", manifest)
          end
        rescue Errno::ENOENT
          raise Bolt::FileError.new("The manifest '#{manifest}' does not exist", manifest)
        end
        code = File.read(File.expand_path(manifest))
        filename = manifest
      end
      result = BoltRunner.with_runner(config, inventory) do |runner|
        runner.apply_manifest(code, targets, filename, noop)
      end
      JSON.parse(result.to_json)
    end

    class BoltRunner
      # Creates a temporary project so no settings are picked up
      # WARNING: puppetdb config and orch config which do not use the project may
      # still be loaded
      def self.with_runner(config_data, inventory_data)
        Dir.mktmpdir do |project_path|
          runner = new(Bolt::Util.deep_clone(config_data), Bolt::Util.deep_clone(inventory_data), project_path)
          yield runner
        end
      end

      def initialize(config_data, inventory_data, project_path)
        Bolt::Logger.initialize_logging

        @config_data = config_data || {}
        @inventory_data = inventory_data || {}
        @project_path = project_path
        @analytics = Bolt::Analytics::NoopClient.new
      end

      def config
        @config ||= Bolt::Config.new(Bolt::Project.create_project(@project_path), @config_data)
      end

      def inventory
        @inventory ||= Bolt::Inventory.create_version(@inventory_data, config.transport, config.transports, plugins)
      end

      def plugins
        @plugins ||= Bolt::Plugin.setup(config, pal)
      end

      def puppetdb_client
        plugins.puppetdb_client
      end

      def pal
        @pal ||= Bolt::PAL.new(Bolt::Config::Modulepath.new(config.modulepath),
                               config.hiera_config,
                               config.project.resource_types,
                               config.compile_concurrency,
                               config.trusted_external,
                               config.apply_settings,
                               config.project)
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

      def run_command(command, targets, options)
        executor = Bolt::Executor.new(config.concurrency, @analytics)
        targets = inventory.get_targets(targets)
        executor.run_command(targets, command, options)
      end

      def run_script(script, targets, arguments, options = {})
        executor = Bolt::Executor.new(config.concurrency, @analytics)
        targets = inventory.get_targets(targets)
        executor.run_script(targets, script, arguments, options)
      end

      def download_file(source, dest, targets, options = {})
        executor = Bolt::Executor.new(config.concurrency, @analytics)
        targets = inventory.get_targets(targets)
        executor.download_file(targets, source, dest, options)
      end

      def upload_file(source, dest, targets, options = {})
        executor = Bolt::Executor.new(config.concurrency, @analytics)
        targets = inventory.get_targets(targets)
        executor.upload_file(targets, source, dest, options)
      end

      def apply_manifest(code, targets, filename = nil, noop = false)
        ast = pal.parse_manifest(code, filename)
        executor = Bolt::Executor.new(config.concurrency, @analytics, noop)
        targets = inventory.get_targets(targets)

        pal.in_plan_compiler(executor, inventory, puppetdb_client) do |compiler|
          compiler.call_function('apply_prep', targets)
        end

        pal.with_bolt_executor(executor, inventory, puppetdb_client) do
          Puppet.lookup(:apply_executor).apply_ast(ast, targets, catch_errors: true, noop: noop)
        end
      end
    end
  end
end
