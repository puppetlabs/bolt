# frozen_string_literal: true

require 'bolt/executor'
require 'bolt/error'

module Bolt
  class PAL
    BOLTLIB_PATH = File.join(__FILE__, '../../../bolt-modules')
    MODULES_PATH = File.join(__FILE__, '../../../modules')

    def initialize(config)
      # Nothing works without initialized this global state. Reinitializing
      # is safe and in practice only happen in tests
      self.class.load_puppet
      self.class.configure_logging(config[:log_level])
      # This makes sure we don't accidentally create puppet dirs
      with_puppet_settings { |_| nil }

      @config = config
    end

    # Puppet logging is global so this is class method to avoid confusion
    def self.configure_logging(log_level)
      Puppet[:log_level] = log_level == :debug ? 'debug' : 'notice'
      Puppet::Util::Log.newdestination(:console)
    end

    def self.load_puppet
      if Gem.win_platform?
        # Windows 'fix' for openssl behaving strangely. Prevents very slow operation
        # of random_bytes later when establishing winrm connections from a Windows host.
        # See https://github.com/rails/rails/issues/25805 for background.
        require 'openssl'
        OpenSSL::Random.random_bytes(1)
      end

      begin
        require_relative '../../vendored/require_vendored'
      rescue LoadError
        raise Bolt::CLIError, "Puppet must be installed to execute tasks"
      end

      # Now that puppet is loaded we can include puppet mixins in data types
      Bolt::ResultSet.include_iterable
    end

    # Create a top-level alias for TargetSpec so that users don't have to
    # namespace it with Boltlib, which is just an implementation detail. This
    # allows TargetSpec to feel like a built-in type in bolt, rather than
    # something has been, no pun intended, "bolted on".
    def add_target_spec(compiler)
      compiler.evaluate_string('type TargetSpec = Boltlib::TargetSpec')
    end

    def full_modulepath(modulepath)
      [BOLTLIB_PATH, *modulepath, MODULES_PATH]
    end

    # Runs a block in a PAL script compiler configured for Bolt.  Catches
    # exceptions thrown by the block and re-raises them ensuring they are
    # Bolt::Errors since the script compiler block will squash all exceptions.
    def in_bolt_compiler
      r = Puppet::Pal.in_tmp_environment('bolt', modulepath: full_modulepath(@config[:modulepath]), facts: {}) do |pal|
        pal.with_script_compiler do |compiler|
          add_target_spec(compiler)
          begin
            yield compiler
          rescue Puppet::PreformattedError => err
            # Puppet sometimes rescues exceptions notes the location and reraises.
            # Return the original error.
            if err.cause
              if err.cause.is_a? Bolt::Error
                err.cause
              else
                e = Bolt::CLIError.new(err.cause.message)
                e.set_backtrace(err.cause.backtrace)
                e
              end
            else
              e = Bolt::CLIError.new(err.message)
              e.set_backtrace(err.backtrace)
              e
            end
          rescue StandardError => err
            e = Bolt::CLIError.new(err.message)
            e.set_backtrace(err.backtrace)
            e
          end
        end
      end

      # Plans may return PuppetError but nothing should be throwing them
      if r.is_a?(StandardError) && !r.is_a?(Bolt::PuppetError)
        raise r
      end
      r
    end

    def with_bolt_executor(executor, inventory, pdb_client = nil, &block)
      Puppet.override({ bolt_executor: executor, bolt_inventory: inventory, bolt_pdb_client: pdb_client }, &block)
    end

    def in_plan_compiler(executor, inventory, pdb_client)
      with_bolt_executor(executor, inventory, pdb_client) do
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
        yield
      end
    end

    def list_tasks
      in_bolt_compiler do |compiler|
        tasks = compiler.list_tasks
        tasks.map(&:name).sort.map do |task_name|
          task_sig = compiler.task_signature(task_name)
          [task_name, task_sig.task.description]
        end
      end
    end

    def parse_params(type, object_name, params)
      in_bolt_compiler do |compiler|
        if type == 'task'
          param_spec = compiler.task_signature(object_name)&.task_hash
        elsif type == 'plan'
          plan = compiler.plan_signature(object_name)
          param_spec = plan_hash(object_name, plan) if plan
        end
        param_spec ||= {}

        params.each_with_object({}) do |(name, str), acc|
          type = param_spec.dig('parameters', name, 'type')
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

    def get_task_info(task_name)
      task = in_bolt_compiler do |compiler|
        compiler.task_signature(task_name)
      end

      if task.nil?
        raise Bolt::CLIError, Bolt::Error.unknown_task(task_name)
      end

      task.task_hash
    end

    def list_plans
      in_bolt_compiler do |compiler|
        compiler.list_plans.map { |plan| [plan.name] }.sort
      end
    end

    # This converts a plan signature object into a format approximating the
    # task_hash of a task_signature. Must be called from within bolt compiler
    # to pickup type aliases used in the plan signature.
    def plan_hash(plan_name, plan)
      elements = plan.params_type.elements || []
      parameters = elements.each_with_object({}) do |param, acc|
        acc[param.name] = { 'type' => param.value_type }
        acc[param.name]['default_value'] = nil if param.key_type.is_a?(Puppet::Pops::Types::POptionalType)
      end
      {
        'name' => plan_name,
        'parameters' => parameters
      }
    end

    def get_plan_info(plan_name)
      plan_info = in_bolt_compiler do |compiler|
        plan = compiler.plan_signature(plan_name)
        plan_hash(plan_name, plan) if plan
      end

      if plan_info.nil?
        raise Bolt::CLIError, Bolt::Error.unknown_plan(plan_name)
      end
      plan_info
    end

    def run_task(task_name, targets, params, executor, inventory, description = nil, &eventblock)
      in_task_compiler(executor, inventory) do |compiler|
        compiler.call_function('run_task', task_name, targets, description, params, &eventblock)
      end
    end

    def run_plan(plan_name, params, executor = nil, inventory = nil, pdb_client = nil)
      in_plan_compiler(executor, inventory, pdb_client) do |compiler|
        r = compiler.call_function('run_plan', plan_name, params)
        Bolt::PuppetError.convert_puppet_errors(r)
      end
    end
  end
end
