# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport'

module Bolt
  class Config
    class Orch < Transport
      OPTIONS = {
        "cacert"            => "The path to the CA certificate.",
        "host"              => "Host name.",
        "job-poll-interval" => "Set interval to poll orchestrator for job status.",
        "job-poll-timeout"  => "Set time to wait for orchestrator job status.",
        "service-url"       => "The URL of the orchestrator API.",
        "task-environment"  => "The environment the orchestrator loads task code from.",
        "token-file"        => "The path to the token file."
      }.freeze

      DEFAULTS = {
        "task-environment" => "production"
      }.freeze

      private def validate
        validate_type(String, 'cacert', 'host', 'service-url', 'task-environment', 'token-file')
        validate_type(Integer, 'job-poll-interval', 'job-poll-timeout')

        if config['cacert']
          @config['cacert'] = File.expand_path(config['cacert'], @boltdir)
          Bolt::Util.validate_file('cacert', config['cacert'])
        end

        if config['token-file']
          @config['token-file'] = File.expand_path(config['token-file'], @boltdir)
          Bolt::Util.validate_file('token-file', config['token-file'])
        end
      end
    end
  end
end
