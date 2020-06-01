# frozen_string_literal: true

require 'bolt/applicator'
require 'bolt/executor'
require 'bolt/error'
require 'bolt/plan_result'
require 'bolt/util'
require 'etc'

module Bolt
  class PAL
    BOLTLIB_PATH = File.expand_path('../../bolt-modules', __dir__)
    MODULES_PATH = File.expand_path('../../modules', __dir__)

    # PALError is used to convert errors from executing puppet code into
    # Bolt::Errors
    class PALError < Bolt::Error
      # Puppet sometimes rescues exceptions notes the location and reraises.
      # Return the original error.
      def self.from_preformatted_error(err)
        if err.cause&.is_a? Bolt::Error
          err.cause
        else
          from_error(err.cause || err)
        end
      end

      # Generate a Bolt::Pal::PALError for non-bolt errors
      def self.from_error(err)
        e = new(err.message)
        e.set_backtrace(err.backtrace)
        e
      end

      def initialize(msg)
        super(msg, 'bolt/pal-error')
      end
    end

    attr_reader :modulepath

    def initialize(modulepath, hiera_config, resource_types, max_compiles = Etc.nprocessors,
                   trusted_external = nil, apply_settings = {}, project = nil)
      # Nothing works without initialized this global state. Reinitializing
      # is safe and in practice only happens in tests
      self.class.load_puppet

      @original_modulepath = modulepath
      @modulepath = [BOLTLIB_PATH, *modulepath, MODULES_PATH]
      @hiera_config = hiera_config
      @trusted_external = trusted_external
      @apply_settings = apply_settings
      @max_compiles = max_compiles
      @resource_types = resource_types
      @project = project

      @logger = Logging.logger[self]
      if modulepath && !modulepath.empty?
        @logger.info("Loading modules from #{@modulepath.join(File::PATH_SEPARATOR)}")
      end

      @loaded = false
    end

    # Puppet logging is global so this is class method to avoid confusion
    def self.configure_logging
      Puppet::Util::Log.destinations.clear
      Puppet::Util::Log.newdestination(Logging.logger['Puppet'])
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

    # Runs a block in a PAL script compiler configured for Bolt.  Catches
    # exceptions thrown by the block and re-raises them ensuring they are
    # Bolt::Errors since the script compiler block will squash all exceptions.
    def in_bolt_compiler
      # TODO: If we always call this inside a bolt_executor we can remove this here
      setup
      r = Puppet::Pal.in_tmp_environment('bolt', modulepath: @modulepath, facts: {}) do |pal|
        Puppet.override(bolt_project: @project,
                        yaml_plan_instantiator: Bolt::PAL::YamlPlan::Loader) do
          pal.with_script_compiler do |compiler|
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
                  "unless explicitly defined. (file: #{e.file}, line: #{e.line}, column: #{e.pos})"
                PALError.new(message)
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
        bolt_executor: executor,
        bolt_inventory: inventory,
        bolt_pdb_client: pdb_client,
        apply_executor: applicator || Applicator.new(
          inventory,
          executor,
          @modulepath,
          # Skip syncing built-in plugins, since we vendor some Puppet 6
          # versions of "core" types, which are already present on the agent,
          # but may cause issues on Puppet 5 agents.
          @original_modulepath,
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
      Dir.mktmpdir('bolt') do |dir|
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
      end
    end

    # Parses a snippet of Puppet manifest code and returns the AST represented
    # in JSON.
    def parse_manifest(code, filename)
      setup
      Puppet::Pops::Parser::EvaluatingParser.new.parse_string(code, filename)
    rescue Puppet::Error => e
      raise Bolt::PAL::PALError, "Failed to parse manifest: #{e}"
    end

    def list_tasks
      in_bolt_compiler do |compiler|
        tasks = compiler.list_tasks
        tasks.map(&:name).sort.each_with_object([]) do |task_name, data|
          task_sig = compiler.task_signature(task_name)
          unless task_sig.task_hash['metadata']['private']
            data << [task_name, task_sig.task_hash['metadata']['description']]
          end
        end
      end
    end

    def list_modulepath
      @modulepath - [BOLTLIB_PATH, MODULES_PATH]
    end

    def parse_params(type, object_name, params)
      in_bolt_compiler do |compiler|
        if type == 'task'
          param_spec = compiler.task_signature(object_name)&.task_hash&.dig('parameters')
        elsif type == 'plan'
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

    def list_plans
      in_bolt_compiler do |compiler|
        errors = []
        plans = compiler.list_plans(nil, errors).map { |plan| [plan.name] }.sort
        errors.each do |error|
          @logger.warn(error.details['original_error'])
        end
        plans
      end
    end

    def get_plan_info(plan_name)
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

        defaults = plan.parameters.reject { |_, value| value.nil? }.to_h
        signature_params = Set.new(plan.parameters.map(&:first))
        parameters = plan.tags(:param).each_with_object({}) do |param, params|
          name = param.name
          if signature_params.include?(name)
            params[name] = { 'type' => param.types.first }
            params[name]['sensitive'] = param.types.first =~ /\ASensitive(\[.*\])?\z/ ? true : false
            params[name]['default_value'] = defaults[name] if defaults.key?(name)
            params[name]['description'] = param.text unless param.text.empty?
          else
            @logger.warn("The documented parameter '#{name}' does not exist in plan signature")
          end
        end

        {
          'name' => plan_name,
          'description' => description,
          'parameters' => parameters,
          'module' => mod
        }

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
          params[name]['default_value'] = param.value
          params[name]['description'] = param.description if param.description
        end
        {
          'name' => plan_name,
          'description' => plan.description,
          'parameters' => parameters,
          'module' => mod
        }
      end
    end

    def convert_plan(plan_path)
      Puppet[:tasks] = true
      transpiler = YamlPlan::Transpiler.new
      transpiler.transpile(plan_path)
    end

    # Returns a mapping of all modules available to the Bolt compiler
    #
    # @return [Hash{String => Array<Hash{Symbol => String,nil}>}]
    #   A hash that associates each directory on the module path with an array
    #   containing a hash of information for each module in that directory.
    #   The information hash provides the name, version, and a string
    #   indicating whether the module belongs to an internal module group.
    def list_modules
      internal_module_groups = { BOLTLIB_PATH => 'Plan Language Modules',
                                 MODULES_PATH => 'Packaged Modules' }

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

    def generate_types
      require 'puppet/face/generate'
      in_bolt_compiler do
        generator = Puppet::Generate::Type
        inputs = generator.find_inputs(:pcore)
        FileUtils.mkdir_p(@resource_types)
        generator.generate(inputs, @resource_types, true)
      end
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
  end
end
