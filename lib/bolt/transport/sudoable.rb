# frozen_string_literal: true

require 'shellwords'
require 'bolt/transport/base'

module Bolt
  module Transport
    class Sudoable < Base
      def self.validate_sudo_options(options)
        run_as_cmd = options['run-as-command']
        if run_as_cmd && (!run_as_cmd.is_a?(Array) || run_as_cmd.any? { |n| !n.is_a?(String) })
          raise Bolt::ValidationError, "run-as-command must be an Array of Strings, received #{run_as_cmd}"
        end
      end

      def self.sudo_prompt
        '[sudo] Bolt needs to run as another user, password: '
      end

      def run_command(target, command, options = {})
        with_connection(target) do |conn|
          conn.running_as(options['_run_as']) do
            output = conn.execute(command, sudoable: true)
            Bolt::Result.for_command(target,
                                     output.stdout.string,
                                     output.stderr.string,
                                     output.exit_code,
                                     'command', command)
          end
        end
      end

      def upload(target, source, destination, options = {})
        with_connection(target) do |conn|
          conn.running_as(options['_run_as']) do
            conn.with_tempdir do |dir|
              basename = File.basename(destination)
              tmpfile = File.join(dir.to_s, basename)
              conn.copy_file(source, tmpfile)
              # pass over file ownership if we're using run-as to be a different user
              dir.chown(conn.run_as)
              result = conn.execute(['mv', '-f', tmpfile, destination], sudoable: true)
              if result.exit_code != 0
                message = "Could not move temporary file '#{tmpfile}' to #{destination}: #{result.stderr.string}"
                raise Bolt::Node::FileError.new(message, 'MV_ERROR')
              end
            end
            Bolt::Result.for_upload(target, source, destination)
          end
        end
      end

      def run_script(target, script, arguments, options = {})
        # unpack any Sensitive data
        arguments = unwrap_sensitive_args(arguments)

        with_connection(target) do |conn|
          conn.running_as(options['_run_as']) do
            conn.with_tempdir do |dir|
              path = conn.write_executable(dir.to_s, script)
              dir.chown(conn.run_as)
              output = conn.execute([path, *arguments], sudoable: true)
              Bolt::Result.for_command(target,
                                       output.stdout.string,
                                       output.stderr.string,
                                       output.exit_code,
                                       'script', script)
            end
          end
        end
      end

      def run_task(target, task, arguments, options = {})
        implementation = select_implementation(target, task)
        executable = implementation['path']
        input_method = implementation['input_method']
        extra_files = implementation['files']

        with_connection(target) do |conn|
          conn.running_as(options['_run_as']) do
            stdin, output = nil
            command = []
            execute_options = {}
            execute_options[:interpreter] = select_interpreter(executable, target.options['interpreters'])
            interpreter_debug = if execute_options[:interpreter]
                                  " using '#{execute_options[:interpreter]}' interpreter"
                                end
            # log the arguments with sensitive data redacted, do NOT log unwrapped_arguments
            logger.debug("Running '#{executable}' with #{arguments.to_json}#{interpreter_debug}")
            # unpack any Sensitive data
            arguments = unwrap_sensitive_args(arguments)

            conn.with_tempdir do |dir|
              if extra_files.empty?
                task_dir = dir
              else
                # TODO: optimize upload of directories
                arguments['_installdir'] = dir.to_s
                task_dir = File.join(dir.to_s, task.tasks_dir)
                dir.mkdirs([task.tasks_dir] + extra_files.map { |file| File.dirname(file['name']) })
                extra_files.each do |file|
                  conn.copy_file(file['path'], File.join(dir.to_s, file['name']))
                end
              end

              remote_task_path = conn.write_executable(task_dir, executable)

              if STDIN_METHODS.include?(input_method)
                stdin = JSON.dump(arguments)
              end

              if ENVIRONMENT_METHODS.include?(input_method)
                execute_options[:environment] = envify_params(arguments)
              end

              if conn.run_as && stdin
                # Inject interpreter in to wrapper script and remove from execute options
                wrapper = make_wrapper_stringio(remote_task_path, stdin, execute_options[:interpreter])
                execute_options.delete(:interpreter)
                remote_wrapper_path = conn.write_executable(dir, wrapper, 'wrapper.sh')
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
                                  output.exit_code,
                                  task.name)
          end
        end
      end

      def make_wrapper_stringio(task_path, stdin, interpreter = nil)
        if interpreter
          StringIO.new(<<~SCRIPT)
            #!/bin/sh
            '#{interpreter}' '#{task_path}' <<'EOF'
            #{stdin}
            EOF
            SCRIPT
        else
          StringIO.new(<<~SCRIPT)
            #!/bin/sh
            '#{task_path}' <<'EOF'
            #{stdin}
            EOF
            SCRIPT
        end
      end
    end
  end
end
