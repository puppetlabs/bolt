module Bolt
  Config = Struct.new(:concurrency,
                      :user,
                      :password,
                      :tty,
                      :insecure,
                      :transport) do

    DEFAULTS = {
      concurrency: 100,
      tty: false,
      insecure: false,
      transport: 'ssh'
    }.freeze

    def initialize(**kwargs)
      super()
      DEFAULTS.merge(kwargs).each { |k, v| self[k] = v }
    end
  end
end
