# frozen_string_literal: true

require 'bolt/pal'
require 'bolt/util'

module BoltServer
  module PE
    class PAL < Bolt::PAL
      # PE_BOLTLIB_PATH is intended to function exactly like the BOLTLIB_PATH used
      # in Bolt::PAL. Paths and variable names are similar to what exists in
      # Bolt::PAL, but with a 'PE' prefix.
      PE_BOLTLIB_PATH = '/opt/puppetlabs/server/apps/bolt-server/pe-bolt-modules'

      # For now at least, we maintain an entirely separate codedir from
      # puppetserver by default, so that filesync can work properly. If filesync
      # is not used, this can instead match the usual puppetserver codedir.
      # See the `orchestrator.bolt.codedir` tk config setting.
      DEFAULT_BOLT_CODEDIR = '/opt/puppetlabs/server/data/orchestration-services/code'

      # This function is nearly identical to Bolt::Pal's `with_puppet_settings` with the
      # one difference that we set the codedir to point to actual code, rather than the
      # tmpdir. We only use this funtion inside the PEBolt::PAL initializer so that Puppet
      # is correctly configured to pull environment configuration correctly. If we don't
      # set codedir in this way: when we try to load and interpolate the modulepath it
      # won't correctly load.
      def with_pe_pal_init_settings(codedir, environmentpath, basemodulepath)
        Dir.mktmpdir('pe-bolt') do |dir|
          cli = []
          Puppet::Settings::REQUIRED_APP_SETTINGS.each do |setting|
            dir = setting == :codedir ? codedir : dir
            cli << "--#{setting}" << dir
          end
          cli << "--environmentpath" << environmentpath
          cli << "--basemodulepath" << basemodulepath
          Puppet.settings.send(:clear_everything_for_tests)
          Puppet.initialize_settings(cli)
          yield
          # Ensure the puppet settings go back to what bolt expects after
          # we finish with the settings we need for PEBolt::PAL init.
          with_puppet_settings { |_| nil }
        end
      end

      def initialize(plan_executor_config, environment_name, hiera_config = nil, max_compiles = nil)
        # Bolt::PAL#initialize takes the modulepath as its first argument, but we
        # want to customize it later, so we pass an empty value:
        super([], hiera_config, max_compiles)

        codedir = plan_executor_config['codedir'] || DEFAULT_BOLT_CODEDIR
        environmentpath = plan_executor_config['environmentpath'] || "#{codedir}/environments"
        basemodulepath = plan_executor_config['basemodulepath'] || "#{codedir}/modules:/opt/puppetlabs/puppet/modules"

        with_pe_pal_init_settings(codedir, environmentpath, basemodulepath) do
          environment = Puppet.lookup(:environments).get!(environment_name)

          # In the instance where the environment is "production" but no production dir
          # exists, the lookup will succeed, but the configuration will be mostly empty.
          # For other environments the lookup will fail, but for production we don't
          # want cryptic messages sent to the user about combining `nil` with a string.
          # Thus if we do get here and `path_to_env` is empty, just assume it's the
          # default production environment and continue.
          #
          # This should hopefully match puppet's behavior for the default 'production'
          # environment: _technically_ that environment always exists, but if the dir
          # isn't there it won't find the module and fail with "plan not found" rather
          # than "environment doesn't exist"
          if environment.configuration.path_to_env
            bolt_config = File.join(environment.configuration.path_to_env, 'bolt.yaml')
          end
          # If we find a bolt.yaml config in the environment root, we load that instead of
          # environment.conf to find the modulepath. modulepath will be the _only_ setting
          # that will work from bolt.yaml in plans in PE.
          modulepath_dirs = if bolt_config && File.exist?(bolt_config)
                              Bolt::Util.read_config_file(bolt_config)['modulepath'].split(File::PATH_SEPARATOR)
                            else
                              environment.modulepath
                            end

          # A new modulepath is created from scratch (rather than using super's @modulepath)
          # so that we can have full control over all the entries in modulepath. In the future
          # it's likely we will need to preceed _both_ Bolt::PAL::BOLTLIB_PATH _and_
          # Bolt::PAL::MODULES_PATH which would be more complex if we tried to use @modulepath since
          # we need to append our modulepaths and exclude modules shiped in bolt gem code
          @original_modulepath = modulepath_dirs
          @modulepath = [PE_BOLTLIB_PATH, Bolt::PAL::BOLTLIB_PATH, *modulepath_dirs]
        end
      end
    end
  end
end
