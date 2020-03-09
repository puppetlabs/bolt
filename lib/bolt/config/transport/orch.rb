# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class Orch < Base
        OPTIONS = {
          "cacert"            => { type: String,
                                   desc: "The path to the CA certificate." },
          "host"              => { type: String,
                                   desc: "Host name." },
          "job-poll-interval" => { type: Integer,
                                   desc: "Set interval to poll orchestrator for job status." },
          "job-poll-timeout"  => { type: Integer,
                                   desc: "Set time to wait for orchestrator job status." },
          "service-url"       => { type: String,
                                   desc: "The URL of the orchestrator API." },
          "task-environment"  => { type: String,
                                   desc: "The environment the orchestrator loads task code from." },
          "token-file"        => { type: String,
                                   desc: "The path to the token file." }
        }.freeze

        DEFAULTS = {
          "task-environment" => "production"
        }.freeze

        private def validate
          super

          if @config['cacert']
            @config['cacert'] = File.expand_path(@config['cacert'], @boltdir)
            Bolt::Util.validate_file('cacert', @config['cacert'])
          end

          if @config['token-file']
            @config['token-file'] = File.expand_path(@config['token-file'], @boltdir)
            Bolt::Util.validate_file('token-file', @config['token-file'])
          end
        end
      end
    end
  end
end
