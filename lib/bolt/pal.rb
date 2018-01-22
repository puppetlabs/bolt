# TODO: This is currently used only for testing. I will refactor the CLI to use
# this in a separate PR
module Bolt
  class PAL
    BOLTLIB_PATH = File.join(__FILE__, '../../../modules')

    def initialize(config)
      # TODO: how should we manage state? Does noop go here?
      # This allows us to copypaste from BOLT::CLI for now
      @config = config
    end

    # WARNING: Nothing in here works without calling this!
    def self.load_puppet
      begin
        require_relative '../../vendored/require_vendored'
      rescue LoadError
        raise Bolt::CLIError, "Puppet must be installed to execute tasks"
      end

      # Now that puppet is loaded we can include puppet mixins in data types
      Bolt::ResultSet.include_iterable

      Puppet::Util::Log.newdestination(:console)
      Puppet[:log_level] = 'notice'
      # Puppet[:log_level] = if @config[:log_level] == :debug
      #                       'debug'
      #                     else
      #                       'notice'
      #                     end
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
            # For now return the original error.
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

      if r.is_a? StandardError
        raise r
      end
      r
    end

    def with_bolt_executor(executor, &block)
      Puppet.override(bolt_executor: executor, &block)
    end

    def in_plan_compiler(noop)
      executor = Bolt::Executor.new(@config, noop, true)
      with_bolt_executor(executor) do
        with_puppet_settings do |opts|
          in_bolt_compiler(opts) do |compiler|
            yield compiler
          end
        end
      end
    end

    def in_task_compiler(noop)
      executor = Bolt::Executor.new(@config, noop)
      with_bolt_executor(executor) do
        in_bolt_compiler(opts) do |compiler|
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
  end
end
