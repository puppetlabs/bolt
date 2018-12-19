# frozen_string_literal: true

require 'bolt/error'

module PlanExecutor
  class Applicator
    def initialize(inventory, executor, config)
      @inventory = inventory
      @executor = executor
      @config = config
    end

    def raise_not_implemented(feature)
      raise Bolt::Error.new("#{feature} not implemented for plan executor service.",
                            'bolt.plan-executor/not-implemented')
    end

    def apply(_args, _apply_body, _scope)
      raise_not_implemented("apply")
    end

    def build_plugin_tarball
      raise_not_implemented("build_plugin_tarball")
    end

    def custom_facts_task
      raise_not_implemented('custom_facts_task')
    end
  end
end
