# frozen_string_literal: true

module Acceptance
  module BoltCommandHelper
    # A helper to build a bolt command used in acceptance testing
    # @param [Beaker::Host] host the host to execute the command on
    # @param [String] command the command to execute on the bolt SUT
    # @param [Hash] flags the command flags to append to the command
    # @option flags [String] '--nodes' the nodes to run on
    # @option flags [String] '--user' the user to run the command as
    # @option flags [String] '--password' the password for the user
    # @option flags [nil] '--no-host-key-check' specify nil to use
    # @option flags [nil] '--no-ssl' specify nil to use
    # @param [Hash] opts the options hash for this method
    def bolt_command_on(host, command, flags = {}, opts = {})
      bolt_command = command.dup
      flags.each { |k, v| bolt_command << " #{k} #{v}" }

      case host['platform']
      when /windows/
        execute_powershell_script_on(host, bolt_command, opts)
      when /osx/
        env = 'source /etc/profile  ~/.bash_profile ~/.bash_login ~/.profile &&'
        on(host, env + ' ' + bolt_command)
      else
        on(host, bolt_command, opts)
      end
    end

    def default_modulepath
      case bolt['platform']
      when /windows/
        home = on(bolt, 'cygpath -m $(printenv USERPROFILE)').stdout.chomp
        File.join(home, '.puppetlabs/bolt/modules')
      else
        '$HOME/.puppetlabs/bolt/modules'
      end
    end

    def modulepath(extra)
      case bolt['platform']
      when /windows/
        "\"#{default_modulepath};#{extra}\""
      else
        "#{default_modulepath}:#{extra}"
      end
    end
  end
end
