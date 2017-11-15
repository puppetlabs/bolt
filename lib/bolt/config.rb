require 'logger'

module Bolt
  Config = Struct.new(
    :concurrency,
    :format,
    :insecure,
    :log_destination,
    :log_level,
    :password,
    :run_as,
    :sudo,
    :sudo_password,
    :transport,
    :tty,
    :user
  ) do
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

    def escalate?
      sudo || run_as
    end
  end
end
