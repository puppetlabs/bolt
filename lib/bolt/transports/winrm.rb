require 'winrm'

module Bolt
  module Transports
    module WinRM
      def execute(endpoint, user, command, password, shell = :powershell)
        connection = ::WinRM::Connection.new(endpoint: endpoint,
                                             user: user,
                                             password: password)
        connection.shell(shell) do |sh|
          sh.run(command) do |stdout, stderr|
            print stdout
            print stderr
          end
        end
      end
      module_function :execute
    end
  end
end
