require 'net/ssh'

module Bolt
  module Transports
    class SSH
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
          puts ssh.exec!(command)
        end
      end
    end
  end
end
