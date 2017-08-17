require 'net/ssh'

module Bolt
  class SSH < Node
    def initialize(host, user, port = nil, password = nil)
      @host = host
      @user = user
      @port = port
      @password = password
    end

    def execute(command)
      options = {}
      options[:port] = @port if @port
      options[:password] = @password if @password

      Net::SSH.start(@host, @user, **options) do |ssh|
        ssh.exec!(command) do |_, stream, data|
          $stdout << data if stream == :stdout
          $stderr << data if stream == :stderr
        end
      end
    end
  end
end
