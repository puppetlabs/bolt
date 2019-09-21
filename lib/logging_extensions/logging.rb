# frozen_string_literal: true

require 'logging'

module LoggingExtensions
  # the logging gem always sets itself up to initialize little-plugger
  # https://github.com/TwP/logging/commit/5aeeffaaa9fe483c2258a23d3b9e92adfafb3b2e
  # little-plugger calls Gem.find_files, incurring an expensive gem scan
  def initialize_plugins; end
end

# monkey patch Logging to override the extended method with a no-op
Logging.extend(LoggingExtensions)
