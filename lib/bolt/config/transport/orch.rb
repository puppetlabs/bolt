# frozen_string_literal: true

require_relative '../../../bolt/error'
require_relative '../../../bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class Orch < Base
        OPTIONS = %w[
          cacert
          host
          job-poll-interval
          job-poll-timeout
          read-timeout
          service-url
          task-environment
          token-file
        ].freeze

        DEFAULTS = {
          "task-environment" => "production"
        }.freeze

        private def validate
          super

          if @config['cacert']
            @config['cacert'] = File.expand_path(@config['cacert'], @project)
            Bolt::Util.validate_file('cacert', @config['cacert'])
          end

          if @config['token-file']
            @config['token-file'] = File.expand_path(@config['token-file'], @project)
            Bolt::Util.validate_file('token-file', @config['token-file'])
          end
        end
      end
    end
  end
end
