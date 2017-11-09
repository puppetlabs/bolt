require 'logger'

module Bolt
  Config = Struct.new(:concurrency,
                      :user,
                      :password,
                      :key,
                      :tty,
                      :insecure,
                      :transport,
                      :log_level,
                      :log_destination) do
    DEFAULTS = {
      concurrency: 100,
      tty: false,
      insecure: false,
      transport: 'ssh',
      log_level: Logger::WARN,
      log_destination: STDERR
    }.freeze

    def initialize(**kwargs)
      super()
      DEFAULTS.merge(kwargs).each { |k, v| self[k] = v }
    end
  end
end
