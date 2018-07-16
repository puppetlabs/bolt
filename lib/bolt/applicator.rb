# frozen_string_literal: true

require 'json'
require 'open3'
require 'bolt/task'
require 'concurrent'

module Bolt
  class Applicator
    def initialize(inventory, executor, modulepath, pdb_config, hiera_config, max_compiles)
      @inventory = inventory
      @executor = executor
      @modulepath = modulepath
      @pdb_config = pdb_config
      @hiera_config = hiera_config ? validate_hiera_config(hiera_config) : nil

      @pool = Concurrent::ThreadPoolExecutor.new(max_threads: max_compiles)
    end

    private def libexec
      @libexec ||= File.join(Gem::Specification.find_by_name('bolt').gem_dir, 'libexec')
    end

    def catalog_apply_task
      @catalog_apply_task ||= begin
        path = File.join(libexec, 'apply_catalog.rb')
        impl = { 'name' => 'apply_catalog.rb', 'path' => path, 'requirements' => [], 'supports_noop' => true }
        Task.new('apply_catalog', [impl], 'stdin')
      end
    end

    def compile(target, ast, plan_vars)
      trusted = Puppet::Context::TrustedInformation.new('local', target.host, {})

      catalog_input = {
        code_ast: ast,
        modulepath: @modulepath,
        pdb_config: @pdb_config,
        hiera_config: @hiera_config,
        target: {
          name: target.host,
          facts: @inventory.facts(target),
          variables: @inventory.vars(target).merge(plan_vars),
          trusted: trusted.to_h
        }
      }

      bolt_catalog_exe = File.join(libexec, 'bolt_catalog')

      old_path = ENV['PATH']
      ENV['PATH'] = "#{RbConfig::CONFIG['bindir']}#{File::PATH_SEPARATOR}#{old_path}"
      out, err, stat = Open3.capture3('ruby', bolt_catalog_exe, 'compile', stdin_data: catalog_input.to_json)
      ENV['PATH'] = old_path

      raise ApplyError.new(target.to_s, err) unless stat.success?
      JSON.parse(out)
    end

    def validate_hiera_config(hiera_config)
      if File.exist?(File.path(hiera_config))
        data = File.open(File.path(hiera_config), "r:UTF-8") { |f| YAML.safe_load(f.read) }
        unless data['version'] == 5
          raise ApplyError.new("All Targets", "Hiera v5 is required.")
        end
        hiera_config
      end
    end

    def apply(args, apply_body, scope)
      raise(ArgumentError, 'apply requires a TargetSpec') if args.empty?
      type0 = Puppet.lookup(:pal_script_compiler).type('TargetSpec')
      Puppet::Pal.assert_type(type0, args[0], 'apply targets')

      params = {}
      if args.count > 1
        type1 = Puppet.lookup(:pal_script_compiler).type('Hash[String, Data]')
        Puppet::Pal.assert_type(type1, args[1], 'apply options')
        params = args[1]
      end

      # collect plan vars and merge them over target vars
      plan_vars = scope.to_hash
      %w[trusted server_facts facts].each { |k| plan_vars.delete(k) }

      targets = @inventory.get_targets(args[0])
      ast = Puppet::Pops::Serialization::ToDataConverter.convert(apply_body, rich_data: true, symbol_to_string: true)
      notify = proc { |_| nil }

      @executor.log_action('apply catalog', targets) do
        futures = targets.map do |target|
          Concurrent::Future.execute(executor: @pool) do
            @executor.with_node_logging("Compiling manifest block", [target]) do
              compile(target, ast, plan_vars)
            end
          end
        end

        result_promises = targets.zip(futures).flat_map do |target, future|
          @executor.queue_execute([target]) do |transport, batch|
            @executor.with_node_logging("Applying manifest block", batch) do
              arguments = params.clone
              arguments['catalog'] = future.value
              raise future.reason if future.rejected?
              transport.batch_task(batch, catalog_apply_task, arguments, {}, &notify)
            end
          end
        end

        @executor.await_results(result_promises)
      end
    end
  end
end
