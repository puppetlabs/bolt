require 'net/ssh'

module Bolt
  class SSH < Node
    def initialize(host, user, port = nil, password = nil)
      @host = host
      @user = user
      @port = port
      @password = password
    end

    def connect
      options = {}
      options[:port] = @port if @port
      options[:password] = @password if @password

      @session = Net::SSH.start(@host, @user, **options)
    end

    def disconnect
      @session.close if @session && !@session.closed?
    end

    def execute(command)
      @session.exec!(command) do |_, stream, data|
        $stdout << data if stream == :stdout
        $stderr << data if stream == :stderr
      end
    end
  end
end
