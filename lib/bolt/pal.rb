# frozen_string_literal: true

require 'bolt/applicator'
require 'bolt/executor'
require 'bolt/error'
require 'bolt/pal/compiler_service'
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
      def self.from_preformatted_error(err)
        if err.cause&.is_a? Bolt::Error
          err.cause
        else
          from_error(err)
        end
      end

      # Generate a Bolt::Pal::PALError for non-bolt errors
      def self.from_error(err)
        # Use the original error message if available
        message = err.cause ? err.cause.message : err.message

        # Provide the location of an error if it came from a plan
        details = if defined?(err.file) && err.file
                    { file:   err.file,
                      line:   err.line,
                      column: err.pos }.compact
                  else
                    {}
                  end

        e = new(message, details)

        e.set_backtrace(err.backtrace)
        e
      end

      def initialize(msg, details = {})
        super(msg, 'bolt/pal-error', details)
      end
    end

    attr_reader :modulepath, :user_modulepath

    def initialize(modulepath, hiera_config, resource_types, max_compiles = Etc.nprocessors,
                   trusted_external = nil, apply_settings = {}, project = nil)
      @user_modulepath = modulepath
      @modulepath = [BOLTLIB_PATH, *modulepath, MODULES_PATH]
      @hiera_config = hiera_config
      @trusted_external = trusted_external
      @apply_settings = apply_settings
      @max_compiles = max_compiles
      @resource_types = resource_types
      @project = project

      @logger = Bolt::Logger.logger(self)
      if modulepath && !modulepath.empty?
        @logger.debug("Loading modules from #{@modulepath.join(File::PATH_SEPARATOR)}")
      end

      @compiler_service = Bolt::PAL::CompilerService.new(project, @modulepath)
    end

    # Runs a block in a PAL script compiler configured for Bolt.  Catches
    # exceptions thrown by the block and re-raises them ensuring they are
    # Bolt::Errors since the script compiler block will squash all exceptions.
    def in_bolt_compiler(&blk)
      @compiler_service.start
      r = begin
            @compiler_service.perform(&blk)
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

      # Plans may return PuppetError but nothing should be throwing them
      if r.is_a?(StandardError) && !r.is_a?(Bolt::PuppetError)
        raise r
      end
      r
    end

    def with_bolt_executor(executor, inventory, pdb_client = nil, &block)
      opts = {
        bolt_executor: executor,
        bolt_inventory: inventory,
        bolt_pdb_client: pdb_client,
        apply_executor: Applicator.new(
          inventory,
          executor,
          @modulepath,
          # Skip syncing built-in plugins, since we vendor some Puppet 6
          # versions of "core" types, which are already present on the agent,
          # but may cause issues on Puppet 5 agents.
          @user_modulepath,
          @project,
          pdb_client,
          @hiera_config,
          @max_compiles,
          @apply_settings
        )
      }
      Puppet.override(opts, &block)
    end

    # TODO: PUP-8553 should replace this
    # Parses a snippet of Puppet manifest code and returns the AST represented
    # in JSON.
    def parse_manifest(code, filename, tasks_mode = false)
      in_bolt_compiler do
        previous_tasks = Puppet[:tasks]
        Puppet[:tasks] = tasks_mode
        Puppet::Pops::Parser::EvaluatingParser.new.parse_string(code, filename)
      ensure
        Puppet[:tasks] = previous_tasks
      end
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
          params[name]['default_value'] = param.value unless param.value.nil?
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
      in_bolt_compiler do |compiler|
        with_bolt_executor(executor, inventory) do
          params = params.merge('_bolt_api_call' => true, '_catch_errors' => true)
          compiler.call_function('run_task', task_name, targets, description, params)
        end
      end
    end

    def run_plan(plan_name, params, executor = nil, inventory = nil, pdb_client = nil)
      in_bolt_compiler do |compiler|
        with_bolt_executor(executor, inventory, pdb_client) do |compiler|
          r = compiler.call_function('run_plan', plan_name, params.merge('_bolt_api_call' => true))
          Bolt::PlanResult.from_pcore(r, 'success')
        end
      end
    rescue Bolt::Error => e
      Bolt::PlanResult.new(e, 'failure')
    end
  end
end
