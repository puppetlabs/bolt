# frozen_string_literal: true

require 'r10k/cli'
require 'bolt/r10k_log_proxy'
require 'bolt/error'

# This class is used to install modules from a Puppetfile to a module directory.
#
module Bolt
  class Puppetfile
    class Installer
      def initialize(config = {})
        @config = config
      end

      def install(path, moduledir)
        unless File.exist?(path)
          raise Bolt::FileError.new(
            "Could not find a Puppetfile at #{path}",
            path
          )
        end

        r10k_opts = {
          root:       File.dirname(path),
          puppetfile: path.to_s,
          moduledir:  moduledir.to_s
        }

        settings = R10K::Settings.global_settings.evaluate(@config)
        R10K::Initializers::GlobalInitializer.new(settings).call
        install_action = R10K::Action::Puppetfile::Install.new(r10k_opts, nil)

        # Override the r10k logger with a proxy to our own logger
        R10K::Logging.instance_variable_set(:@outputter, Bolt::R10KLogProxy.new)

        install_action.call
      rescue R10K::Error => e
        raise PuppetfileError, e
      end
    end
  end
end
