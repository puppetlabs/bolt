# frozen_string_literal: true

require 'base64'
require 'concurrent'
require 'find'
require 'json'
require 'logging'
require 'minitar'
require 'open3'
require 'bolt/task'
require 'bolt/apply_result'
require 'bolt/util/puppet_log_level'

module Bolt
  class Applicator
    def initialize(inventory, executor, modulepath, plugin_dirs, pdb_client, hiera_config, max_compiles)
      @inventory = inventory
      @executor = executor
      @modulepath = modulepath
      @plugin_dirs = plugin_dirs
      @pdb_client = pdb_client
      @hiera_config = hiera_config ? validate_hiera_config(hiera_config) : nil
      @analytics = executor&.analytics

      @pool = Concurrent::ThreadPoolExecutor.new(max_threads: max_compiles)
      @logger = Logging.logger[self]
      @plugin_tarball = Concurrent::Delay.new do
        build_plugin_tarball do |mod|
          search_dirs = []
          search_dirs << mod.plugins if mod.plugins?
          search_dirs << mod.pluginfacts if mod.pluginfacts?
          search_dirs << mod.files if mod.files?
          search_dirs
        end
      end
    end

    private def libexec
      @libexec ||= File.join(Gem::Specification.find_by_name('bolt').gem_dir, 'libexec')
    end

    def custom_facts_task
      @custom_facts_task ||= begin
        path = File.join(libexec, 'custom_facts.rb')
        file = { 'name' => 'custom_facts.rb', 'path' => path }
        metadata = { 'supports_noop' => true, 'input_method' => 'stdin' }
        Bolt::Task.new(name: 'apply_helpers::custom_facts', files: [file], metadata: metadata)
      end
    end

    def catalog_apply_task
      @catalog_apply_task ||= begin
        path = File.join(libexec, 'apply_catalog.rb')
        file = { 'name' => 'apply_catalog.rb', 'path' => path }
        metadata = { 'supports_noop' => true, 'input_method' => 'stdin' }
        Bolt::Task.new(name: 'apply_helpers::apply_catalog', files: [file], metadata: metadata)
      end
    end

    def compile(target, ast, plan_vars)
      trusted = Puppet::Context::TrustedInformation.new('local', target.host, {})

      catalog_input = {
        code_ast: ast,
        modulepath: @modulepath,
        pdb_config: @pdb_client.config.to_hash,
        hiera_config: @hiera_config,
        target: {
          name: target.host,
          facts: @inventory.facts(target),
          variables: @inventory.vars(target).merge(plan_vars),
          trusted: trusted.to_h
        },
        inventory: @inventory.data_hash
      }

      bolt_catalog_exe = File.join(libexec, 'bolt_catalog')
      old_path = ENV['PATH']
      ENV['PATH'] = "#{RbConfig::CONFIG['bindir']}#{File::PATH_SEPARATOR}#{old_path}"
      out, err, stat = Open3.capture3('ruby', bolt_catalog_exe, 'compile', stdin_data: catalog_input.to_json)
      ENV['PATH'] = old_path

      # stderr may contain formatted logs from Puppet's logger or other errors.
      # Print them in order, but handle them separately. Anything not a formatted log is assumed
      # to be an error message.
      logs = err.lines.map do |l|
        begin
          JSON.parse(l)
        rescue StandardError
          l
        end
      end
      logs.each do |log|
        if log.is_a?(String)
          @logger.error(log.chomp)
        else
          log.map { |k, v| [k.to_sym, v] }.each do |level, msg|
            bolt_level = Bolt::Util::PuppetLogLevel::MAPPING[level]
            @logger.send(bolt_level, "#{target.name}: #{msg.chomp}")
          end
        end
      end

      raise(ApplyError, target.name) unless stat.success?
      JSON.parse(out)
    end

    def validate_hiera_config(hiera_config)
      if File.exist?(File.path(hiera_config))
        data = File.open(File.path(hiera_config), "r:UTF-8") { |f| YAML.safe_load(f.read, [Symbol]) }
        unless data['version'] == 5
          raise Bolt::ParseError, "Hiera v5 is required, found v#{data['version'] || 3} in #{hiera_config}"
        end
        hiera_config
      end
    end

    def apply(args, apply_body, scope)
      raise(ArgumentError, 'apply requires a TargetSpec') if args.empty?
      type0 = Puppet.lookup(:pal_script_compiler).type('TargetSpec')
      Puppet::Pal.assert_type(type0, args[0], 'apply targets')

      @executor.report_function_call('apply')

      options = {}
      if args.count > 1
        type1 = Puppet.lookup(:pal_script_compiler).type('Hash[String, Data]')
        Puppet::Pal.assert_type(type1, args[1], 'apply options')
        options = args[1]
      end

      # collect plan vars and merge them over target vars
      plan_vars = scope.to_hash
      %w[trusted server_facts facts].each { |k| plan_vars.delete(k) }

      targets = @inventory.get_targets(args[0])

      apply_ast(apply_body, targets, options, plan_vars)
    end

    # Count the number of top-level statements in the AST.
    def count_statements(ast)
      case ast
      when Puppet::Pops::Model::Program
        count_statements(ast.body)
      when Puppet::Pops::Model::BlockExpression
        ast.statements.count
      else
        1
      end
    end

    def apply_ast(raw_ast, targets, options, plan_vars = {})
      @analytics&.event('Apply', 'ast', 'statements', count_statements(raw_ast))

      ast = Puppet::Pops::Serialization::ToDataConverter.convert(raw_ast, rich_data: true, symbol_to_string: true)

      notify = proc { |_| nil }

      r = @executor.log_action('apply catalog', targets) do
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
              catalog = future.value
              raise future.reason if future.rejected?

              arguments = {
                'catalog' => Puppet::Pops::Types::PSensitiveType::Sensitive.new(catalog),
                'plugins' => Puppet::Pops::Types::PSensitiveType::Sensitive.new(plugins),
                '_noop' => options['_noop']
              }

              @analytics&.event('Apply', 'ast', 'resources', catalog['resources'].size)
              results = transport.batch_task(batch, catalog_apply_task, arguments, options, &notify)
              Array(results).map { |result| ApplyResult.from_task_result(result) }
            end
          end
        end

        @executor.await_results(result_promises)
      end

      if !r.ok && !options['_catch_errors']
        raise Bolt::ApplyFailure, r
      end
      r
    end

    def plugins
      @plugin_tarball.value ||
        raise(Bolt::Error.new("Failed to pack module plugins: #{@plugin_tarball.reason}", 'bolt/plugin-error'))
    end

    def build_plugin_tarball
      start_time = Time.now
      sio = StringIO.new
      output = Minitar::Output.new(Zlib::GzipWriter.new(sio))

      Puppet.lookup(:current_environment).override_with(modulepath: @plugin_dirs).modules.each do |mod|
        search_dirs = yield mod

        parent = Pathname.new(mod.path).parent
        files = Find.find(*search_dirs).select { |file| File.file?(file) }

        files.each do |file|
          tar_path = Pathname.new(file).relative_path_from(parent)
          @logger.debug("Packing plugin #{file} to #{tar_path}")
          stat = File.stat(file)
          content = File.binread(file)
          output.tar.add_file_simple(
            tar_path.to_s,
            data: content,
            size: content.size,
            mode: stat.mode & 0o777,
            mtime: stat.mtime
          )
        end
      end

      duration = Time.now - start_time
      @logger.debug("Packed plugins in #{duration * 1000} ms")

      output.close
      Base64.encode64(sio.string)
    ensure
      output&.close
    end
  end
end
