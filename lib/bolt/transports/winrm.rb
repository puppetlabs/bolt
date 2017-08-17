require 'winrm'

module Bolt
  module Transports
    class WinRM
      def initialize(endpoint, user, password, shell = :powershell)
        @endpoint = endpoint
        @user = user
        @password = password
        @shell = shell
      end

      def execute(command)
        connection = ::WinRM::Connection.new(endpoint: @endpoint,
                                             user: @user,
                                             password: @password)
        connection.shell(@shell) do |sh|
          sh.run(command) do |stdout, stderr|
            print stdout
            print stderr
          end
        end
      end
    end
  end
end
