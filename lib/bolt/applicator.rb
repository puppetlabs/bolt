# frozen_string_literal: true

require 'base64'
require 'bolt/apply_result'
require 'bolt/apply_target'
require 'bolt/config'
require 'bolt/error'
require 'bolt/task'
require 'bolt/util/puppet_log_level'
require 'find'
require 'json'
require 'logging'
require 'open3'

module Bolt
  class Applicator
    def initialize(inventory, executor, modulepath, plugin_dirs, pdb_client, hiera_config, max_compiles, apply_settings)
      # lazy-load expensive gem code
      require 'concurrent'

      @inventory = inventory
      @executor = executor
      @modulepath = modulepath
      @plugin_dirs = plugin_dirs
      @pdb_client = pdb_client
      @hiera_config = hiera_config ? validate_hiera_config(hiera_config) : nil
      @apply_settings = apply_settings || {}

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
        metadata = { 'supports_noop' => true, 'input_method' => 'stdin',
                     'implementations' => [
                       { 'name' => 'custom_facts.rb' },
                       { 'name' => 'custom_facts.rb', 'remote' => true }
                     ] }
        Bolt::Task.new('apply_helpers::custom_facts', metadata, [file])
      end
    end

    def catalog_apply_task
      @catalog_apply_task ||= begin
                                path = File.join(libexec, 'apply_catalog.rb')
                                file = { 'name' => 'apply_catalog.rb', 'path' => path }
                                metadata = { 'supports_noop' => true, 'input_method' => 'stdin',
                                             'implementations' => [
                                               { 'name' => 'apply_catalog.rb' },
                                               { 'name' => 'apply_catalog.rb', 'remote' => true }
                                             ] }
                                Bolt::Task.new('apply_helpers::apply_catalog', metadata, [file])
                              end
    end

    def query_resources_task
      @query_resources_task ||= begin
        path = File.join(libexec, 'query_resources.rb')
        file = { 'name' => 'query_resources.rb', 'path' => path }
        metadata = { 'supports_noop' => true, 'input_method' => 'stdin',
                     'implementations' => [
                       { 'name' => 'query_resources.rb' },
                       { 'name' => 'query_resources.rb', 'remote' => true }
                     ] }

        Bolt::Task.new('apply_helpers::query_resources', metadata, [file])
      end
    end

    def compile(target, catalog_input)
      # This simplified Puppet node object is what .local uses to determine the
      # certname of the target
      node = Puppet::Node.from_data_hash('name' => target.name,
                                         'parameters' => { 'clientcert' => target.name })
      trusted = Puppet::Context::TrustedInformation.local(node)
      catalog_input[:target] = {
        name: target.name,
        facts: @inventory.facts(target).merge('bolt' => true),
        variables: @inventory.vars(target),
        trusted: trusted.to_h
      }

      bolt_catalog_exe = File.join(libexec, 'bolt_catalog')
      old_path = ENV['PATH']
      ENV['PATH'] = "#{RbConfig::CONFIG['bindir']}#{File::PATH_SEPARATOR}#{old_path}"
      out, err, stat = Open3.capture3('ruby', bolt_catalog_exe, 'compile', stdin_data: catalog_input.to_json)
      ENV['PATH'] = old_path

      # Any messages logged by Puppet will be on stderr as JSON hashes, so we
      # parse those and store them here. Any message on stderr that is not
      # properly JSON formatted is assumed to be an error message.  If
      # compilation was successful, we print the logs as they may include
      # important warnings. If compilation failed, we don't print the logs as
      # they are likely redundant with the error that caused the failure, which
      # will be handled separately.
      logs = err.lines.map do |line|
        JSON.parse(line)
      rescue JSON::ParserError
        { 'level' => 'err', 'message' => line }
      end

      result = JSON.parse(out)
      if stat.success?
        logs.each do |log|
          bolt_level = Bolt::Util::PuppetLogLevel::MAPPING[log['level'].to_sym]
          message = log['message'].chomp
          @logger.send(bolt_level, "#{target.name}: #{message}")
        end
        result
      else
        raise ApplyError.new(target.name, result['message'])
      end
    end

    def validate_hiera_config(hiera_config)
      if File.exist?(File.path(hiera_config))
        data = File.open(File.path(hiera_config), "r:UTF-8") { |f| YAML.safe_load(f.read, [Symbol]) }
        if data.nil?
          return nil
        elsif data['version'] != 5
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
        options = args[1].transform_keys { |k| k.sub(/^_/, '').to_sym }
      end

      plan_vars = scope.to_hash(true, true)

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
      ast = Puppet::Pops::Serialization::ToDataConverter.convert(raw_ast, rich_data: true, symbol_to_string: true)

      # Serialize as pcore for *Result* objects
      plan_vars = Puppet::Pops::Serialization::ToDataConverter.convert(plan_vars,
                                                                       rich_data: true,
                                                                       symbol_as_string: true,
                                                                       type_by_reference: true,
                                                                       local_reference: false)

      scope = {
        code_ast: ast,
        modulepath: @modulepath,
        pdb_config: @pdb_client.config.to_hash,
        hiera_config: @hiera_config,
        plan_vars: plan_vars,
        # This data isn't available on the target config hash
        config: @inventory.transport_data_get
      }

      description = options[:description] || 'apply catalog'

      r = @executor.log_action(description, targets) do
        futures = targets.map do |target|
          Concurrent::Future.execute(executor: @pool) do
            @executor.with_node_logging("Compiling manifest block", [target]) do
              compile(target, scope)
            end
          end
        end

        result_promises = targets.zip(futures).flat_map do |target, future|
          @executor.queue_execute([target]) do |transport, batch|
            @executor.with_node_logging("Applying manifest block", batch) do
              catalog = future.value
              if future.rejected?
                batch.map do |batch_target|
                  # If an unhandled exception occurred, wrap it in an ApplyError
                  error = if future.reason.is_a?(Bolt::ApplyError)
                            future.reason
                          else
                            Bolt::ApplyError.new(batch_target, future.reason.message)
                          end
                  result = Bolt::ApplyResult.new(batch_target, error: error.to_h)
                  @executor.publish_event(type: :node_result, result: result)
                  result
                end
              else
                arguments = {
                  'catalog' => Puppet::Pops::Types::PSensitiveType::Sensitive.new(catalog),
                  'plugins' => Puppet::Pops::Types::PSensitiveType::Sensitive.new(plugins),
                  'apply_settings' => @apply_settings,
                  '_task' => catalog_apply_task.name,
                  '_noop' => options[:noop]
                }

                callback = proc do |event|
                  if event[:type] == :node_result
                    event = event.merge(result: ApplyResult.from_task_result(event[:result]))
                  end
                  @executor.publish_event(event)
                end
                # Respect the run_as default set on the executor
                options[:run_as] = @executor.run_as if @executor.run_as && !options.key?(:run_as)

                results = transport.batch_task(batch, catalog_apply_task, arguments, options, &callback)
                Array(results).map { |result| ApplyResult.from_task_result(result) }
              end
            end
          end
        end

        @executor.await_results(result_promises)
      end

      # Allow for report to exclude event metrics (apply_result doesn't require it to be present)
      resource_counts = r.ok_set.map { |result| result.event_metrics&.fetch('total') }.compact
      @executor.report_apply(count_statements(raw_ast), resource_counts)

      if !r.ok && !options[:catch_errors]
        raise Bolt::ApplyFailure, r
      end
      r
    end

    def plugins
      @plugin_tarball.value ||
        raise(Bolt::Error.new("Failed to pack module plugins: #{@plugin_tarball.reason}", 'bolt/plugin-error'))
    end

    def build_plugin_tarball
      # lazy-load expensive gem code
      require 'minitar'
      require 'zlib'

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
