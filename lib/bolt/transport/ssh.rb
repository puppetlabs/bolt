# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/transport/base'
require 'json'
require 'shellwords'

module Bolt
  module Transport
    class SSH < Base
      def self.options
        %w[port user password sudo-password private-key host-key-check connect-timeout tmpdir run-as tty run-as-command]
      end

      PROVIDED_FEATURES = ['shell'].freeze

      def self.validate(options)
        logger = Logging.logger[self]

        if options['sudo-password'] && options['run-as'].nil?
          logger.warn("--sudo-password will not be used without specifying a " \
                       "user to escalate to with --run-as")
        end

        host_key = options['host-key-check']
        unless !!host_key == host_key
          raise Bolt::ValidationError, 'host-key-check option must be a Boolean true or false'
        end

        if (key_opt = options['private-key'])
          unless key_opt.instance_of?(String) || (key_opt.instance_of?(Hash) && key_opt.include?('key-data'))
            raise Bolt::ValidationError,
                  "private-key option must be the path to a private key file or a hash containing the 'key-data'"
          end
        end

        timeout_value = options['connect-timeout']
        unless timeout_value.is_a?(Integer) || timeout_value.nil?
          error_msg = "connect-timeout value must be an Integer, received #{timeout_value}:#{timeout_value.class}"
          raise Bolt::ValidationError, error_msg
        end

        run_as_cmd = options['run-as-command']
        if run_as_cmd && (!run_as_cmd.is_a?(Array) || run_as_cmd.any? { |n| !n.is_a?(String) })
          raise Bolt::ValidationError, "run-as-command must be an Array of Strings, received #{run_as_cmd}"
        end
      end

      def initialize
        super

        require 'net/ssh'
        require 'net/scp'
        begin
          require 'net/ssh/krb'
        rescue LoadError
          logger.debug {
            "Authentication method 'gssapi-with-mic' is not available. "\
            "Please install the kerberos gem with `gem install net-ssh-krb`"
          }
        end

        @transport_logger = Logging.logger[Net::SSH]
        @transport_logger.level = :warn
      end

      def with_connection(target, load_config = true)
        conn = Connection.new(target, @transport_logger, load_config)
        conn.connect
        yield conn
      ensure
        begin
          conn&.disconnect
        rescue StandardError => ex
          logger.info("Failed to close connection to #{target.uri} : #{ex.message}")
        end
      end

      def upload(target, source, destination, options = {})
        with_connection(target) do |conn|
          conn.running_as(options['_run_as']) do
            conn.with_remote_tempdir do |dir|
              basename = File.basename(destination)
              tmpfile = "#{dir}/#{basename}"
              conn.write_remote_file(source, tmpfile)
              # pass over file ownership if we're using run-as to be a different user
              dir.chown(conn.run_as)
              result = conn.execute(['mv', tmpfile, destination], sudoable: true)
              if result.exit_code != 0
                message = "Could not move temporary file '#{tmpfile}' to #{destination}: #{result.stderr.string}"
                raise Bolt::Node::FileError.new(message, 'MV_ERROR')
              end
            end
            Bolt::Result.for_upload(target, source, destination)
          end
        end
      end

      def run_command(target, command, options = {})
        with_connection(target) do |conn|
          conn.running_as(options['_run_as']) do
            output = conn.execute(command, sudoable: true)
            Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
          end
        end
      end

      def run_script(target, script, arguments, options = {})
        # unpack any Sensitive data
        arguments = unwrap_sensitive_args(arguments)

        with_connection(target) do |conn|
          conn.running_as(options['_run_as']) do
            conn.with_remote_tempdir do |dir|
              remote_path = conn.write_remote_executable(dir, script)
              dir.chown(conn.run_as)
              output = conn.execute([remote_path, *arguments], sudoable: true)
              Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
            end
          end
        end
      end

      def run_task(target, task, arguments, options = {})
        implementation = task.select_implementation(target, PROVIDED_FEATURES)
        executable = implementation['path']
        input_method = implementation['input_method']
        extra_files = implementation['files']
        input_method ||= 'both'

        # unpack any Sensitive data
        arguments = unwrap_sensitive_args(arguments)
        with_connection(target, options.fetch('_load_config', true)) do |conn|
          conn.running_as(options['_run_as']) do
            stdin, output = nil
            command = []
            execute_options = {}

            conn.with_remote_tempdir do |dir|
              if extra_files.empty?
                task_dir = dir
              else
                # TODO: optimize upload of directories
                arguments['_installdir'] = dir.to_s
                task_dir = File.join(dir.to_s, task.tasks_dir)
                dir.mkdirs([task.tasks_dir] + extra_files.map { |file| File.dirname(file['name']) })
                extra_files.each do |file|
                  conn.write_remote_file(file['path'], File.join(dir.to_s, file['name']))
                end
              end

              remote_task_path = conn.write_remote_executable(task_dir, executable)

              if STDIN_METHODS.include?(input_method)
                stdin = JSON.dump(arguments)
              end

              if ENVIRONMENT_METHODS.include?(input_method)
                execute_options[:environment] = envify_params(arguments)
              end

              if conn.run_as && stdin
                wrapper = make_wrapper_stringio(remote_task_path, stdin)
                remote_wrapper_path = conn.write_remote_executable(dir, wrapper, 'wrapper.sh')
                command << remote_wrapper_path
              else
                command << remote_task_path
                execute_options[:stdin] = stdin
              end
              dir.chown(conn.run_as)

              execute_options[:sudoable] = true if conn.run_as
              output = conn.execute(command, execute_options)
            end
            Bolt::Result.for_task(target, output.stdout.string,
                                  output.stderr.string,
                                  output.exit_code)
          end
        end
      end

      def make_wrapper_stringio(task_path, stdin)
        StringIO.new(<<-SCRIPT)
#!/bin/sh
'#{task_path}' <<'EOF'
#{stdin}
EOF
SCRIPT
      end

      def connected?(target)
        with_connection(target) { true }
      rescue Bolt::Node::ConnectError
        false
      end
    end
  end
end

require 'bolt/transport/ssh/connection'
