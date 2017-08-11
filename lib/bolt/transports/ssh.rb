require 'net/ssh'

module Bolt::Transports::SSH
  def execute(host, user, command, port=nil, password=nil)
    options = {}
    options[:port] = port if port
    options[:password] = password if password

    Net::SSH.start(host, user, **options) do |ssh|
      puts ssh.exec!(command)
    end
  end
  module_function :execute
end
