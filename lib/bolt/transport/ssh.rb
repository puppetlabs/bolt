require 'bolt/node/errors'
require 'bolt/transport/base'
require 'json'
require 'shellwords'

module Bolt
  module Transport
    class SSH < Base
      STDIN_METHODS       = %w[both stdin].freeze
      ENVIRONMENT_METHODS = %w[both environment].freeze

      def initialize(_config)
        super

        require 'net/ssh'
        require 'net/scp'
        begin
          require 'net/ssh/krb'
        rescue LoadError
          logger.debug {
            "Authentication method 'gssapi-with-mic' is not available"
          }
        end
      end

      def with_connection(target)
        conn = Connection.new(target)
        conn.connect
        yield conn
      ensure
        begin
          conn.disconnect if conn
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
              result = conn.execute("mv '#{tmpfile}' '#{destination}'", sudoable: true)
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
        with_connection(target) do |conn|
          conn.running_as(options['_run_as']) do
            conn.with_remote_tempdir do |dir|
              remote_path = conn.write_remote_executable(dir, script)
              dir.chown(conn.run_as)
              output = conn.execute("'#{remote_path}' #{Shellwords.join(arguments)}", sudoable: true)
              Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
            end
          end
        end
      end

      def run_task(target, task, input_method, arguments, options = {})
        with_connection(target) do |conn|
          conn.running_as(options['_run_as']) do
            export_args = {}
            stdin, output = nil

            if STDIN_METHODS.include?(input_method)
              stdin = JSON.dump(arguments)
            end

            if ENVIRONMENT_METHODS.include?(input_method)
              export_args = arguments.map do |env, val|
                "PT_#{env}='#{val}'"
              end.join(' ')
            end

            command = export_args.empty? ? '' : "#{export_args} "

            execute_options = {}

            conn.with_remote_tempdir do |dir|
              remote_task_path = conn.write_remote_executable(dir, task)
              if conn.run_as && stdin
                wrapper = make_wrapper_stringio(remote_task_path, stdin)
                remote_wrapper_path = conn.write_remote_executable(dir, wrapper, 'wrapper.sh')
                command += "'#{remote_wrapper_path}'"
              else
                command += "'#{remote_task_path}'"
                execute_options[:stdin] = stdin
              end
              dir.chown(conn.run_as)

              execute_options[:sudoable] = true if conn.run_as
              output = conn.execute(command, **execute_options)
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
'#{task_path}' <<EOF
#{stdin}
EOF
SCRIPT
      end
    end
  end
end

require 'bolt/transport/ssh/connection'
