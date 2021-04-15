# frozen_string_literal: true

require 'bolt/applicator'
require 'bolt/executor'
require 'bolt/error'
require 'bolt/plan_result'
require 'bolt/util'
require 'bolt/config/modulepath'
require 'etc'

module Bolt
  class PAL
    # PALError is used to convert errors from executing puppet code into
    # Bolt::Errors
    class PALError < Bolt::Error
      def self.from_preformatted_error(err)
        error = if err.cause.is_a? Bolt::Error
                  err.cause
                else
                  from_error(err)
                end

        # Provide the location of an error if it came from a plan
        details = {}
        details[:file]   = err.file if defined?(err.file)
        details[:line]   = err.line if defined?(err.line)
        details[:column] = err.pos if defined?(err.pos)

        error.add_filelineno(details.compact)
        error
      end

      # Generate a Bolt::Pal::PALError for non-bolt errors
      def self.from_error(err)
        # Use the original error message if available
        message = err.cause ? err.cause.message : err.message
        e = new(message)
        e.set_backtrace(err.backtrace)
        e
      end

      def initialize(msg, details = {})
        super(msg, 'bolt/pal-error', details)
      end
    end

    def initialize(modulepath, hiera_config, resource_types, max_compiles = Etc.nprocessors,
                   trusted_external = nil, apply_settings = {}, project = nil)
      unless modulepath.is_a?(Bolt::Config::Modulepath)
        msg = "Type error in PAL: modulepath must be a Bolt::Config::Modulepath"
        raise Bolt::Error.new(msg, "bolt/execution-error")
      end
      # Nothing works without initialized this global state. Reinitializing
      # is safe and in practice only happens in tests
      self.class.load_puppet
      @modulepath = modulepath
      @hiera_config = hiera_config
      @trusted_external = trusted_external
      @apply_settings = apply_settings
      @max_compiles = max_compiles
      @resource_types = resource_types
      @project = project

      @logger = Bolt::Logger.logger(self)
      unless user_modulepath.empty?
        @logger.debug("Loading modules from #{full_modulepath.join(File::PATH_SEPARATOR)}")
      end

      @loaded = false
    end

    def full_modulepath
      @modulepath.full_modulepath
    end

    def user_modulepath
      @modulepath.user_modulepath
    end

    # Puppet logging is global so this is class method to avoid confusion
    def self.configure_logging
      Puppet::Util::Log.destinations.clear
      Puppet::Util::Log.newdestination(Bolt::Logger.logger('Puppet'))
      # Defer all log level decisions to the Logging library by telling Puppet
      # to log everything
      Puppet.settings[:log_level] = 'debug'
    end

    def self.load_puppet
      if Bolt::Util.windows?
        # Windows 'fix' for openssl behaving strangely. Prevents very slow operation
        # of random_bytes later when establishing winrm connections from a Windows host.
        # See https://github.com/rails/rails/issues/25805 for background.
        require 'openssl'
        OpenSSL::Random.random_bytes(1)
      end

      begin
        require 'puppet_pal'
      rescue LoadError
        raise Bolt::Error.new("Puppet must be installed to execute tasks", "bolt/puppet-missing")
      end

      require 'bolt/pal/logging'
      require 'bolt/pal/issues'
      require 'bolt/pal/yaml_plan/loader'
      require 'bolt/pal/yaml_plan/transpiler'

      # Now that puppet is loaded we can include puppet mixins in data types
      Bolt::ResultSet.include_iterable
    end

    def setup
      unless @loaded
        # This is slow so don't do it until we have to
        Bolt::PAL.load_puppet

        # Make sure we don't create the puppet directories
        with_puppet_settings { |_| nil }
        @loaded = true
      end
    end

    # Create a top-level alias for TargetSpec and PlanResult so that users don't have to
    # namespace it with Boltlib, which is just an implementation detail. This
    # allows them to feel like a built-in type in bolt, rather than
    # something has been, no pun intended, "bolted on".
    def alias_types(compiler)
      compiler.evaluate_string('type TargetSpec = Boltlib::TargetSpec')
      compiler.evaluate_string('type PlanResult = Boltlib::PlanResult')
    end

    # Register all resource types defined in $Project/.resource_types as well as
    # the built in types registered with the runtime_3_init method.
    def register_resource_types(loaders)
      static_loader = loaders.static_loader
      static_loader.runtime_3_init
      if File.directory?(@resource_types)
        Dir.children(@resource_types).each do |resource_pp|
          type_name_from_file = File.basename(resource_pp, '.pp').capitalize
          typed_name = Puppet::Pops::Loader::TypedName.new(:type, type_name_from_file)
          resource_type = Puppet::Pops::Types::TypeFactory.resource(type_name_from_file)
          loaders.static_loader.set_entry(typed_name, resource_type)
        end
      end
    end

    def detect_project_conflict(project, environment)
      return unless project && project.load_as_module?
      # The environment modulepath has stripped out non-existent directories,
      # so we don't need to check for them
      modules = environment.modulepath.flat_map do |path|
        Dir.children(path).select { |name| Puppet::Module.is_module_directory?(name, path) }
      end
      if modules.include?(project.name)
        Bolt::Logger.warn_once(
          "project_shadows_module",
          "The project '#{project.name}' shadows an existing module of the same name"
        )
      end
    end

    # Runs a block in a PAL script compiler configured for Bolt.  Catches
    # exceptions thrown by the block and re-raises them ensuring they are
    # Bolt::Errors since the script compiler block will squash all exceptions.
    def in_bolt_compiler
      # TODO: If we always call this inside a bolt_executor we can remove this here
      setup
      r = Puppet::Pal.in_tmp_environment('bolt', modulepath: full_modulepath, facts: {}) do |pal|
        # Only load the project if it a) exists, b) has a name it can be loaded with
        Puppet.override(bolt_project: @project,
                        yaml_plan_instantiator: Bolt::PAL::YamlPlan::Loader) do
          # Because this has the side effect of loading and caching the list
          # of modules, it must happen *after* we have overridden
          # bolt_project or the project will be ignored
          detect_project_conflict(@project, Puppet.lookup(:environments).get('bolt'))
          pal.with_script_compiler(set_local_facts: false) do |compiler|
            alias_types(compiler)
            register_resource_types(Puppet.lookup(:loaders)) if @resource_types
            begin
              yield compiler
            rescue Bolt::Error => e
              e
            rescue Puppet::DataBinding::LookupError => e
              if e.issue_code == :HIERA_UNDEFINED_VARIABLE
                message = "Interpolations are not supported in lookups outside of an apply block: #{e.message}"
                PALError.new(message)
              else
                PALError.from_preformatted_error(e)
              end
            rescue Puppet::PreformattedError => e
              if e.issue_code == :UNKNOWN_VARIABLE &&
                 %w[facts trusted server_facts settings].include?(e.arguments[:name])
                message = "Evaluation Error: Variable '#{e.arguments[:name]}' is not available in the current scope "\
                          "unless explicitly defined."
                details = { file: e.file, line: e.line, column: e.pos }
                PALError.new(message, details)
              else
                PALError.from_preformatted_error(e)
              end
            rescue StandardError => e
              PALError.from_preformatted_error(e)
            end
          end
        end
      end

      # Plans may return PuppetError but nothing should be throwing them
      if r.is_a?(StandardError) && !r.is_a?(Bolt::PuppetError)
        raise r
      end
      r
    end

    def with_bolt_executor(executor, inventory, pdb_client = nil, applicator = nil, &block)
      setup
      opts = {
        bolt_project: @project,
        bolt_executor: executor,
        bolt_inventory: inventory,
        bolt_pdb_client: pdb_client,
        apply_executor: applicator || Applicator.new(
          inventory,
          executor,
          full_modulepath,
          # Skip syncing built-in plugins, since we vendor some Puppet 6
          # versions of "core" types, which are already present on the agent,
          # but may cause issues on Puppet 5 agents.
          user_modulepath,
          @project,
          pdb_client,
          @hiera_config,
          @max_compiles,
          @apply_settings
        )
      }
      Puppet.override(opts, &block)
    end

    def in_plan_compiler(executor, inventory, pdb_client, applicator = nil)
      with_bolt_executor(executor, inventory, pdb_client, applicator) do
        # TODO: remove this call and see if anything breaks when
        # settings dirs don't actually exist. Plans shouldn't
        # actually be using them.
        with_puppet_settings do
          in_bolt_compiler do |compiler|
            yield compiler
          end
        end
      end
    end

    def in_task_compiler(executor, inventory)
      with_bolt_executor(executor, inventory) do
        in_bolt_compiler do |compiler|
          yield compiler
        end
      end
    end

    # TODO: PUP-8553 should replace this
    def with_puppet_settings
      dir = Dir.mktmpdir('bolt')

      cli = []
      Puppet::Settings::REQUIRED_APP_SETTINGS.each do |setting|
        cli << "--#{setting}" << dir
      end
      Puppet.settings.send(:clear_everything_for_tests)
      Puppet.initialize_settings(cli)
      Puppet::GettextConfig.create_default_text_domain
      Puppet[:trusted_external_command] = @trusted_external
      Puppet.settings[:hiera_config] = @hiera_config
      self.class.configure_logging
      yield
    ensure
      # Delete the tmpdir if it still exists. This check is needed to
      # prevent Bolt from erroring if the tmpdir is somehow deleted
      # before reaching this point.
      FileUtils.remove_entry_secure(dir) if File.exist?(dir)
    end

    # Parses a snippet of Puppet manifest code and returns the AST represented
    # in JSON.
    def parse_manifest(code, filename)
      setup
      Puppet::Pops::Parser::EvaluatingParser.new.parse_string(code, filename)
    rescue Puppet::Error => e
      raise Bolt::PAL::PALError, "Failed to parse manifest: #{e}"
    end

    # Filters content by a list of names and glob patterns specified in project
    # configuration.
    def filter_content(content, patterns)
      return content unless content && patterns

      content.select do |name,|
        patterns.any? { |pattern| File.fnmatch?(pattern, name, File::FNM_EXTGLOB) }
      end
    end

    def list_tasks(filter_content: false)
      in_bolt_compiler do |compiler|
        tasks = compiler.list_tasks.map(&:name).sort.each_with_object([]) do |task_name, data|
          task_sig = compiler.task_signature(task_name)
          unless task_sig.task_hash['metadata']['private']
            data << [task_name, task_sig.task_hash['metadata']['description']]
          end
        end

        filter_content ? filter_content(tasks, @project&.tasks) : tasks
      end
    end

    def parse_params(type, object_name, params)
      in_bolt_compiler do |compiler|
        case type
        when 'task'
          param_spec = compiler.task_signature(object_name)&.task_hash&.dig('parameters')
        when 'plan'
          plan = compiler.plan_signature(object_name)
          param_spec = plan.params_type.elements&.each_with_object({}) { |t, h| h[t.name] = t.value_type } if plan
        end
        param_spec ||= {}

        params.each_with_object({}) do |(name, str), acc|
          type = param_spec[name]
          begin
            parsed = JSON.parse(str, quirks_mode: true)
            # The type may not exist if the module is remote on orch or if a task
            # defines no parameters. Since we treat no parameters as Any we
            # should parse everything in this case
            acc[name] = if type && !type.instance?(parsed)
                          str
                        else
                          parsed
                        end
          rescue JSON::ParserError
            # This value may not be assignable in which case run_* will error
            acc[name] = str
          end
          acc
        end
      end
    end

    def task_signature(task_name)
      in_bolt_compiler do |compiler|
        compiler.task_signature(task_name)
      end
    end

    def get_task(task_name)
      task = task_signature(task_name)

      if task.nil?
        raise Bolt::Error.unknown_task(task_name)
      end

      Bolt::Task.from_task_signature(task)
    end

    def list_plans_with_cache(filter_content: false)
      # Don't filter content yet, so that if users update their plan filters
      # we don't need to refresh the cache
      plan_names = list_plans(filter_content: false).map(&:first)
      plan_cache = if @project
                     Bolt::Util.read_optional_json_file(@project.plan_cache_file, 'Plan cache file')
                   else
                     {}
                   end
      updated = false

      plan_list = plan_names.each_with_object([]) do |plan_name, list|
        info = plan_cache[plan_name] || get_plan_info(plan_name, with_mtime: true)

        # If the plan is a 'local' plan (in the project itself, or the
        # modules/ directory) then verify it hasn't been updated since we
        # cached it. If it has been updated, refresh the cache and use the
        # new data.
        if info['file'] &&
           (File.mtime(info.dig('file', 'path')) <=> info.dig('file', 'mtime')) != 0
          info = get_plan_info(plan_name, with_mtime: true)
          updated = true
          plan_cache[plan_name] = info
        end

        list << [plan_name, info['description']] unless info['private']
      end

      File.write(@project.plan_cache_file, plan_cache.to_json) if updated

      filter_content ? filter_content(plan_list, @project&.plans) : plan_list
    end

    def list_plans(filter_content: false)
      in_bolt_compiler do |compiler|
        errors = []
        plans = compiler.list_plans(nil, errors).map { |plan| [plan.name] }.sort
        errors.each do |error|
          Bolt::Logger.warn("plan_load_error", error.details['original_error'])
        end

        filter_content ? filter_content(plans, @project&.plans) : plans
      end
    end

    def get_plan_info(plan_name, with_mtime: false)
      plan_sig = in_bolt_compiler do |compiler|
        compiler.plan_signature(plan_name)
      end

      if plan_sig.nil?
        raise Bolt::Error.unknown_plan(plan_name)
      end

      # path may be a Pathname object, so make sure to stringify it
      mod = plan_sig.instance_variable_get(:@plan_func).loader.parent.path.to_s

      # If it's a Puppet language plan, use strings to extract data. The only
      # way to tell is to check which filename exists in the module.
      plan_subpath = File.join(plan_name.split('::').drop(1))
      plan_subpath = 'init' if plan_subpath.empty?

      pp_path = File.join(mod, 'plans', "#{plan_subpath}.pp")
      if File.exist?(pp_path)
        require 'puppet-strings'
        require 'puppet-strings/yard'
        PuppetStrings::Yard.setup!
        YARD::Logger.instance.level = :error
        YARD.parse(pp_path)

        plan = YARD::Registry.at("puppet_plans::#{plan_name}")

        description = if plan.tag(:summary)
                        plan.tag(:summary).text
                      elsif !plan.docstring.empty?
                        plan.docstring
                      end

        defaults = plan.parameters.to_h.compact
        signature_params = Set.new(plan.parameters.map(&:first))
        parameters = plan.tags(:param).each_with_object({}) do |param, params|
          name = param.name
          if signature_params.include?(name)
            params[name] = { 'type' => param.types.first }
            params[name]['sensitive'] = param.types.first =~ /\ASensitive(\[.*\])?\z/ ? true : false
            params[name]['default_value'] = defaults[name] if defaults.key?(name)
            params[name]['description'] = param.text if param.text && !param.text.empty?
          else
            Bolt::Logger.warn(
              "missing_plan_parameter",
              "The documented parameter '#{name}' does not exist in signature for plan '#{plan.name}'"
            )
          end
        end

        privie = plan.tag(:private)&.text
        unless privie.nil? || %w[true false].include?(privie.downcase)
          msg = "Plan #{plan_name} key 'private' must be a boolean, received: #{privie}"
          raise Bolt::Error.new(msg, 'bolt/invalid-plan')
        end

        pp_info = {
          'name'        => plan_name,
          'description' => description,
          'parameters'  => parameters,
          'module'      => mod
        }
        pp_info.merge!({ 'private' => privie&.downcase == 'true' }) unless privie.nil?
        pp_info.merge!(get_plan_mtime(plan.file)) if with_mtime
        pp_info

      # If it's a YAML plan, fall back to limited data
      else
        yaml_path = File.join(mod, 'plans', "#{plan_subpath}.yaml")
        plan_content = File.read(yaml_path)
        plan = Bolt::PAL::YamlPlan::Loader.from_string(plan_name, plan_content, yaml_path)

        parameters = plan.parameters.each_with_object({}) do |param, params|
          name = param.name
          type_str = case param.type_expr
                     when Puppet::Pops::Types::PTypeReferenceType
                       param.type_expr.type_string
                     when nil
                       'Any'
                     else
                       param.type_expr
                     end
          params[name] = { 'type' => type_str }
          params[name]['sensitive'] = param.type_expr.instance_of?(Puppet::Pops::Types::PSensitiveType)
          params[name]['default_value'] = param.value unless param.value.nil?
          params[name]['description'] = param.description if param.description
        end

        yaml_info = {
          'name'        => plan_name,
          'description' => plan.description,
          'parameters'  => parameters,
          'module'      => mod
        }
        yaml_info.merge!({ 'private' => plan.private }) unless plan.private.nil?
        yaml_info.merge!(get_plan_mtime(yaml_path)) if with_mtime
        yaml_info
      end
    end

    def get_plan_mtime(path)
      # If the plan is from the project modules/ directory, or is in the
      # project itself, include the last mtime of the file so we can compare
      # if the plan has been updated since it was cached.
      if @project &&
         File.exist?(path) &&
         (path.include?(File.join(@project.path, 'modules')) ||
          path.include?(@project.plans_path.to_s))

        { 'file' => { 'mtime' => File.mtime(path),
                      'path' => path } }
      else
        {}
      end
    end

    def convert_plan(plan)
      path = File.expand_path(plan)

      # If the path doesn't exist, check if it's a plan name
      unless File.exist?(path)
        in_bolt_compiler do |compiler|
          sig = compiler.plan_signature(plan)

          # If the plan was loaded, look for it on the module loader
          # There has to be an easier way to do this...
          if sig
            type = compiler.list_plans.find { |p| p.name == plan }
            path = sig.instance_variable_get(:@plan_func)
                      .loader
                      .find(type)
                      .origin
                      .first
          end
        end
      end

      Puppet[:tasks] = true
      transpiler = YamlPlan::Transpiler.new
      transpiler.transpile(path)
    end

    # Returns a mapping of all modules available to the Bolt compiler
    #
    # @return [Hash{String => Array<Hash{Symbol => String,nil}>}]
    #   A hash that associates each directory on the modulepath with an array
    #   containing a hash of information for each module in that directory.
    #   The information hash provides the name, version, and a string
    #   indicating whether the module belongs to an internal module group.
    def list_modules
      internal_module_groups = { Bolt::Config::Modulepath::BOLTLIB_PATH => 'Plan Language Modules',
                                 Bolt::Config::Modulepath::MODULES_PATH => 'Packaged Modules',
                                 @project.managed_moduledir.to_s => 'Project Dependencies' }

      in_bolt_compiler do
        # NOTE: Can replace map+to_h with transform_values when Ruby 2.4
        #       is the minimum supported version.
        Puppet.lookup(:current_environment).modules_by_path.map do |path, modules|
          module_group = internal_module_groups[path]

          values = modules.map do |mod|
            mod_info = { name: (mod.forge_name || mod.name),
                         version: mod.version }
            mod_info[:internal_module_group] = module_group unless module_group.nil?

            mod_info
          end

          [path, values]
        end.to_h
      end
    end

    def generate_types(cache: false)
      require 'puppet/face/generate'
      in_bolt_compiler do
        generator = Puppet::Generate::Type
        inputs = generator.find_inputs(:pcore)
        FileUtils.mkdir_p(@resource_types)
        cache_plan_info if @project && cache
        generator.generate(inputs, @resource_types, true)
      end
    end

    def cache_plan_info
      # plan_name is an array here
      plans_info = list_plans(filter_content: false).map do |plan_name,|
        data = get_plan_info(plan_name, with_mtime: true)
        { plan_name => data }
      end.reduce({}, :merge)

      FileUtils.touch(@project.plan_cache_file)
      File.write(@project.plan_cache_file, plans_info.to_json)
    end

    def run_task(task_name, targets, params, executor, inventory, description = nil)
      in_task_compiler(executor, inventory) do |compiler|
        params = params.merge('_bolt_api_call' => true, '_catch_errors' => true)
        compiler.call_function('run_task', task_name, targets, description, params)
      end
    end

    def run_plan(plan_name, params, executor = nil, inventory = nil, pdb_client = nil, applicator = nil)
      in_plan_compiler(executor, inventory, pdb_client, applicator) do |compiler|
        r = compiler.call_function('run_plan', plan_name, params.merge('_bolt_api_call' => true))
        Bolt::PlanResult.from_pcore(r, 'success')
      end
    rescue Bolt::Error => e
      Bolt::PlanResult.new(e, 'failure')
    end

    def lookup(key, targets, inventory, executor, _concurrency)
      # Install the puppet-agent package and collect facts. Facts are
      # automatically added to the targets.
      in_plan_compiler(executor, inventory, nil) do |compiler|
        compiler.call_function('apply_prep', targets)
      end

      overrides = {
        bolt_inventory: inventory,
        bolt_project:   @project
      }

      # Do a lookup with a catalog compiler, which uses the 'hierarchy' key in
      # Hiera config.
      results = targets.map do |target|
        node = Puppet::Node.from_data_hash(
          'name'       => target.name,
          'parameters' => { 'clientcert' => target.name }
        )

        trusted = Puppet::Context::TrustedInformation.local(node).to_h

        env_conf = {
          modulepath: @modulepath.full_modulepath,
          facts:      target.facts,
          variables:  target.vars
        }

        with_puppet_settings do
          Puppet::Pal.in_tmp_environment(target.name, **env_conf) do |pal|
            Puppet.override(overrides) do
              Puppet.lookup(:pal_current_node).trusted_data = trusted
              pal.with_catalog_compiler do |compiler|
                Bolt::Result.for_lookup(target, key, compiler.call_function('lookup', key))
              rescue StandardError => e
                Bolt::Result.from_exception(target, e)
              end
            end
          end
        end
      end

      Bolt::ResultSet.new(results)
    end
  end
end
