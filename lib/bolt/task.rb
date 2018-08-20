# frozen_string_literal: true

module Bolt
  Task = Struct.new(
    :name,
    :implementations,
    :input_method,
    :file,
    :metadata
  ) do

    TASK_DEFAULTS = {
      implementations: {},
      input_method: 'both',
      metadata: {}
    }.freeze

    def initialize(task)
      super()
      TASK_DEFAULTS.merge(task).each { |k, v| self[k] = v }
    end
  end
end
