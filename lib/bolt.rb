# frozen_string_literal: true

# loads Logging gem, patching it for perf reasons to disable plugins
require 'logging_extensions/logging'

module Bolt
  # Trigger PR tests REVERT ME
  require_relative 'bolt/executor'
end
