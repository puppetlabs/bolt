# frozen_string_literal: true

require 'bolt/pal'
require 'bolt/util'

module BoltServer
  module PE
    class PAL < Bolt::PAL

      # PE_BOLTLIB_PATH is intended to function exactly like the BOLTLIB_PATH used
      # in Bolt::PAL. Paths and variable names are similar to what exists in
      # Bolt::PAL, but with a 'PE' prefix.
      PE_BOLTLIB_PATH = '/opt/puppetlabs/server/apps/bolt-server/pe-bolt-modules'.freeze

      # For now at least, we maintain an entirely separate codedir from
      # puppetserver by default, so that filesync can work properly. If filesync
      # is not used, this can instead match the usual puppetserver codedir.
      # See the `orchestrator.bolt.codedir` tk config setting.
      DEFAULT_BOLT_CODEDIR = '/opt/puppetlabs/server/data/orchestration-services/code'.freeze

      DATADIR = '/opt/puppetlabs/server/data/orchestration-services'.freeze

      def self.loader_lock
        @loader_lock
      end

      def self.initialize_puppet(config)
        cli = []
        codedir = config['codedir'] || DEFAULT_BOLT_CODEDIR
        environmentpath = config['environmentpath'] || "#{codedir}/environments"
        basemodulepath = config['basemodulepath'] || "#{codedir}/modules:/opt/puppetlabs/puppet/modules"
        Bolt::PAL.load_puppet()
        Puppet::Settings::REQUIRED_APP_SETTINGS.each do |setting|
          dir = setting == :codedir ? codedir : DATADIR
          cli << "--#{setting}" << dir
        end
        cli << "--environmentpath" << environmentpath
        cli << "--basemodeulepath" << basemodulepath
        Puppet.initialize_settings(cli)
        Puppet[:tasks] = true
        Bolt::PAL.configure_logging()
        @loader_lock = Mutex.new()
      end

      # The only reason we need to subclass is to control the modulepath, specifically remove
      # the path to Bolt::PAL::MODULES_PATH
      def initialize(environment_name)
        modulepath_dirs = []
        modulepath_setting_from_bolt = nil
        environment = Puppet.lookup(:environments).get!(environment_name)
        path_to_env = environment.configuration.path_to_env
        basemodulepath = Puppet[:basemodulepath]

        modulepath_dirs = environment.modulepath
        @modulepath = [PE_BOLTLIB_PATH, Bolt::PAL::BOLTLIB_PATH, *modulepath_dirs]
      end
    end
  end
end
