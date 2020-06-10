# frozen_string_literal: true

require 'bolt/project'
require 'bolt/config'
require 'bolt/error'

module Bolt
  class ApplyInventory
    class InvalidFunctionCall < Bolt::Error
      def initialize(function)
        super("The function '#{function}' is not callable within an apply block",
              'bolt.inventory/invalid-function-call')
      end
    end

    attr_reader :config_hash

    def initialize(config_hash = {})
      @config_hash = config_hash
      @targets = {}
    end

    def create_apply_target(target)
      @targets[target.name] = target
    end

    def validate
      @groups.validate
    end

    def version
      2
    end

    def target_implementation_class
      Bolt::ApplyTarget
    end

    def get_targets(*_params)
      raise InvalidFunctionCall, 'get_targets'
    end

    def get_target(*_params)
      raise InvalidFunctionCall, 'get_target'
    end

    # rubocop:disable Naming/AccessorMethodName
    def set_var(*_params)
      raise InvalidFunctionCall, 'set_var'
    end

    def set_feature(*_params)
      raise InvalidFunctionCall, 'set_feature'
    end
    # rubocop:enable Naming/AccessorMethodName

    def vars(target)
      @targets[target.name].vars
    end

    def add_facts(*_params)
      raise InvalidFunctionCall, 'add_facts'
    end

    def facts(target)
      @targets[target.name].facts
    end

    def features(target)
      @targets[target.name].features
    end

    def resource(target, type, title)
      @targets[target.name].resource(type, title)
    end

    def add_to_group(*_params)
      raise InvalidFunctionCall, 'add_to_group'
    end

    def plugin_hooks(target)
      @targets[target.name].plugin_hooks
    end

    def set_config(_target, _key_or_key_path, _value)
      raise InvalidFunctionCall, 'set_config'
    end

    def target_config(target)
      @targets[target.name].config
    end
  end
end
