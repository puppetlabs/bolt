module Acceptance
  module BoltCommandHelper
    # A helper to build a bolt command used in acceptance testing
    # @param [Beaker::Host] host the host to execute the command on
    # @param [String] command the command to execute on the bolt SUT
    # @param [Hash] flags the command flags to append to the command
    # @option flags [String] '--nodes' the nodes to run on
    # @option flags [String] '--user' the user to run the command as
    # @option flags [String] '--password' the password for the user
    # @option flags [nil] '--insecure' specify nil to use
    # @param [Hash] opts the options hash for this method
    def bolt_command_on(host, command, flags = {}, opts = {})
      platform = host['platform']
      bolt_command = command.dup
      flags.each { |k, v| bolt_command << " #{k} #{v}" }

      if platform =~ /windows/
        execute_powershell_script_on(host, bolt_command, opts)
      elsif platform =~ /osx/
        env = 'source /etc/profile  ~/.bash_profile ~/.bash_login ~/.profile &&'
        on(host, env + ' ' + bolt_command)
      else
        on(host, bolt_command, opts)
      end
    end
  end
end
