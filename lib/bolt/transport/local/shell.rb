# frozen_string_literal: true

require 'open3'
require 'bolt/node/output'
require 'bolt/transport/helpers'

module Bolt
  module Transport
    class Local
      class Shell
        attr_accessor :run_as

        def initialize
          @user = Etc.getlogin
          @run_as = nil
        end

        # Run as the specified user for the duration of the block.
        def running_as(user)
          @run_as = user
          yield
        ensure
          @run_as = nil
        end

        def handled_sudo(target, data)
          # TODO
#          if data.lines.include?(sudo_prompt)
#            if target_options['sudo-password']
#
#          else
#            # Cancel the sudo prompt to prevent later commands getting stuck
#            raise Bolt::Node::EscalateError.new(
#              "Sudo password for user #{@user} was not provided for #{target.uri}",
#              'NO_PASSWORD'
#            )
#          end
#        elsif data =~ /^#{@user} is not in the sudoers file\./
#          @logger.debug { data }
#          raise Bolt::Node::EscalateError.new(
#            "User #{@user} does not have sudo permission on #{target.uri}",
#            'SUDO_DENIED'
#          )
#        elsif data =~ /^Sorry, try again\./
#          @logger.debug { data }
#          raise Bolt::Node::EscalateError.new(
#            "Sudo password for user #{@user} not recognized on #{target.uri}",
#            'BAD_PASSWORD'
#          )
#        end
#        false
        end

        def execute(*command, target_opts, options)
          options[:sudoable] = true if options[:sudoable].nil?
          run_as = options[:run_as] || @run_as || target_opts['run-as']

          command_str = execute_prep(command,
                                     options,
                                     sudoable: options[:sudoable],
                                     run_as_command: target_opts['run-as-command'],
                                     run_as: run_as,
                                     conn_user: @user)
          command_arr = Shellwords.split(command_str)
          command_arr = [options[:environment]] + command if options[:environment]

          options[:environment] ||= {}
          if options[:stdin]
            stdout, stderr, rc = Open3.capture3(*command_arr,
                                                stdin_data: options[:stdin],
                                                chdir: options[:dir])
          else
            stdout, stderr, rc = Open3.capture3(*command_arr,
                                                chdir: options[:dir])
          end

          result_output = Bolt::Node::Output.new
          result_output.stdout << stdout unless stdout.nil?
          result_output.stderr << stderr unless stderr.nil?
          result_output.exit_code = rc.exitstatus
          result_output
        end
      end
    end
  end
end
