# frozen_string_literal: true

module Bolt
  class PAL
    class CompilerService
      def initialize(project, modulepath)
        require 'concurrent'

        @project = project
        @modulepath = modulepath
        @queue = Queue.new
      end

      def start(&blk)
        return if @thread
        self.class.load_puppet
        initialize_puppet
        configure_logging

        # XXX raise if already started
        @thread = Thread.new do
          in_bolt_compiler(@project, @modulepath) do |compiler|
            initialize_compiler(compiler)
            loop do
              work = @queue.pop
              func = work[:proc]
              promise = work[:promise]
              result = func.call(compiler)
              promise.set(result)
            end
          end
        end
      end

      def stop
        return unless @thread
        @thread.kill
        @thread.join
      end

      def perform(&blk)
        # If we're already executing in the scope of a compiler (ie. in the
        # worker thread) then just yield the compiler. Otherwise, push a work
        # item onto the queue. This allows the compiler service to be
        # reentrant, avoiding deadlocks if code being run by the compiler needs
        # to access the compiler again.
        compiler = Puppet.lookup(:pal_compiler) { nil }

        if compiler
          yield compiler
        else
          promise = Concurrent::Promise.new
          @queue.push(proc: blk, promise: promise)
          promise.wait!
          promise.value
        end
      end

      def initialize_compiler(compiler)
        detect_project_conflict(@project, Puppet.lookup(:environments).get('bolt'))
        alias_types(compiler)
        register_resource_types(Puppet.lookup(:loaders), @project)
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

      def initialize_puppet
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
          configure_logging
        end
      end

      # Puppet logging is global so this is class method to avoid confusion
      def configure_logging
        Puppet::Util::Log.destinations.clear
        Puppet::Util::Log.newdestination(Bolt::Logger.logger('Puppet'))
        # Defer all log level decisions to the Logging library by telling Puppet
        # to log everything
        Puppet.settings[:log_level] = 'debug'
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
      def register_resource_types(loaders, project)
        return unless project
        static_loader = loaders.static_loader
        static_loader.runtime_3_init
        if File.directory?(project.resource_types)
          Dir.children(project.resource_types).each do |resource_pp|
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
          Bolt::Logger.warn_once("project shadows module",
                                 "The project '#{project.name}' shadows an existing module of the same name")
        end
      end

      # Runs a block in a PAL script compiler configured for Bolt.  Catches
      # exceptions thrown by the block and re-raises them ensuring they are
      # Bolt::Errors since the script compiler block will squash all exceptions.
      def in_bolt_compiler(project, modulepath)
        Puppet::Pal.in_tmp_environment('bolt', modulepath: modulepath, facts: {}) do |pal|
          # Only load the project if it a) exists, b) has a name it can be loaded with
          Puppet.override(bolt_project: project,
                          yaml_plan_instantiator: Bolt::PAL::YamlPlan::Loader) do
            pal.with_script_compiler(set_local_facts: false) do |compiler|
              yield compiler
            end
          end
        end
      end
    end
  end
end

