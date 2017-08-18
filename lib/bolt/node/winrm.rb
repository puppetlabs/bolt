require 'winrm'

module Bolt
  class WinRM < Node
    def initialize(endpoint, user, password, shell = :powershell)
      @endpoint = endpoint
      @user = user
      @password = password
      @shell = shell
      @connection = ::WinRM::Connection.new(endpoint: @endpoint,
                                            user: @user,
                                            password: @password)
    end

    def connect
      @session = @connection.shell(@shell)
    end

    def disconnect
      @session.close if @session
    end

    def execute(command)
      @session.run(command) do |stdout, stderr|
        print stdout
        print stderr
      end
    end
  end
end
