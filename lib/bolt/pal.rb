require 'bolt/executor'
require 'bolt/error'

module Bolt
  class PAL
    BOLTLIB_PATH = File.join(__FILE__, '../../../modules')

    def initialize(config)
      # Nothing works without initialized this global state. Reinitializing
      # is safe and in practice only happen in tests
      self.class.load_puppet
      self.class.configure_logging(config[:log_level])

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

    # Runs a block in a PAL script compiler configured for Bolt.  Catches
    # exceptions thrown by the block and re-raises them ensuring they are
    # Bolt::Errors since the script compiler block will squash all exceptions.
    def in_bolt_compiler(opts = [])
      Puppet.initialize_settings(opts)
      r = Puppet::Pal.in_tmp_environment('bolt', modulepath: [BOLTLIB_PATH] + @config[:modulepath], facts: {}) do |pal|
        pal.with_script_compiler do |compiler|
          begin
            yield compiler
          rescue Puppet::PreformattedError => err
            # Puppet sometimes rescues exceptions notes the location and reraises
            # For now return the original error. Exception cause support was added in Ruby 2.1
            # so we fall back to reporting the error we got for Ruby 2.0.
            if err.respond_to?(:cause) && err.cause
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

      if r.is_a? StandardError
        raise r
      end
      r
    end

    def with_bolt_executor(executor, &block)
      Puppet.override(bolt_executor: executor, &block)
    end

    def in_plan_compiler(executor)
      with_bolt_executor(executor) do
        with_puppet_settings do |opts|
          in_bolt_compiler(opts) do |compiler|
            yield compiler
          end
        end
      end
    end

    def in_task_compiler(executor)
      with_bolt_executor(executor) do
        in_bolt_compiler do |compiler|
          yield compiler
        end
      end
    end

    def with_puppet_settings
      Dir.mktmpdir('bolt') do |dir|
        cli = []
        Puppet::Settings::REQUIRED_APP_SETTINGS.each do |setting|
          cli << "--#{setting}" << dir
        end
        yield cli
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

    def get_task_info(task_name)
      task = in_bolt_compiler do |compiler|
        compiler.task_signature(task_name)
      end
      raise Bolt::CLIError, "Could not find task #{task_name} in your modulepath" if task.nil?
      task.task_hash
    end

    def list_plans
      in_bolt_compiler do |compiler|
        compiler.list_plans.map { |plan| [plan.name] }.sort
      end
    end

    def get_plan_info(plan_name)
      plan = in_bolt_compiler do |compiler|
        compiler.plan_signature(plan_name)
      end
      raise Bolt::CLIError, "Could not find plan #{plan_name} in your modulepath" if plan.nil?
      elements = plan.params_type.elements
      {
        'name' => plan_name,
        'parameters' =>
          unless elements.nil? || elements.empty?
            elements.map { |e|
              p = {
                'name' => e.name,
                'type' => e.value_type
              }
              # TODO: when the default value can be obtained use the actual value instead of nil
              p['default_value'] = nil if e.key_type.is_a?(Puppet::Pops::Types::POptionalType)
              p
            }
          end
      }
    end

    def run_task(object, targets, params, executor, &eventblock)
      in_task_compiler(executor) do |compiler|
        compiler.call_function('run_task', object, targets, params, &eventblock)
      end
    end

    def run_plan(object, params, executor)
      in_plan_compiler(executor) do |compiler|
        compiler.call_function('run_plan', object, params)
      end
    end
  end
end
