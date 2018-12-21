# frozen_string_literal: true

require 'hocon'
require 'bolt_server/base_config'
require 'bolt/error'

module PlanExecutor
  class Config < BoltServer::BaseConfig
    def config_keys
      super + %w[modulepath workers]
    end

    def defaults
      super.merge(
        'port' => 62659,
        'workers' => 1
      )
    end

    def service_name
      'plan-executor'
    end

    def load_env_config
      env_keys.each do |key|
        transformed_key = "BOLT_#{key.tr('-', '_').upcase}"
        next unless ENV.key?(transformed_key)
        @data[key] = ENV[transformed_key]
      end
    end

    def validate
      super
      unless natural?(@data['workers'])
        raise Bolt::ValidationError, "Configured 'workers' must be a positive integer"
      end
    end
  end
end
