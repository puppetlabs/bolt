module Bolt
  Config = Struct.new(:concurrency,
                      :user,
                      :password,
                      :tty,
                      :insecure) do

    DEFAULTS = {
      concurrency: 100,
      tty: false,
      insecure: false
    }.freeze

    def initialize(**kwargs)
      super()
      DEFAULTS.merge(kwargs).each { |k, v| self[k] = v }
    end
  end
end
